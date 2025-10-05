Added the Gitea Helm chart to the cluster.
Pods fail to start, cannot pull images from docker.io.
Bitnami has deprecated its Debian based images, and removed the tags.
Gitea has not updated their Helm chart to reflect this change.
---
Nice command to get values file for a Helm chart, to see options and adjust if needed.
```
helm show values oci://ghcr.io/woodpecker-ci/helm/woodpecker > values.yaml
```
If values are updated, you can do:
```
helm install woodpecker \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  -f values.yaml
```
---
Woodpecker requires a forge to be setup, getting an error from the server pod:
```
can't setup globals: could not setup service manager: forge not configured
```
Setting up GitHub via OAuth client app.
Added these env vars:
```
WOODPECKER_GITHUB: "true"
WOODPECKER_GITHUB_CLIENT: Ov23lifIEwbb8eRsQl4Y
WOODPECKER_GITHUB_SECRET: xxx (in BitWarden)
```
Update Woodpecker via Helm:
```
helm upgrade --install woodpecker oci://ghcr.io/woodpecker-ci/helm/woodpecker -f values.yaml
```
By default there is no Ingress, so I'll add my own.
Ingress works, navigating to URL shows Woodpecker UI.
Login with github.com failes with error on server pod:
```
cannot register sguldemond. registration closed
```
Had to set WOODPECKER_OPEN to True. And remember to re-set the client token.
Now I can login and add my homelab repo.
---
Created a pipeline, got some errors in Woodpecker.
Couldn't easily run linter on the pipeline, so have to push fixes untill it works.
Seems like I cannot run images in privilged mode untill the project is set as trusted.
```
Insufficient trust level to use privileged mode
```
For this you need to be a admin, so I updated the WOODPECKER_ADMIN to "sguldemond" in the Helm values. 
After setting this up, I don't see the option to make the project "trusted".
Works, I needed to login and logout! Refresh the access token.
The CLI is available here: https://github.com/woodpecker-ci/woodpecker/releases
From the UI you can grab a token and locally do:
```
export WOODPECKER_SERVER="http://woodpecker.macmini.home"
export WOODPECKER_TOKEN="xxx"
```
Then you can run the cli locally, e.g.:
```
woodpecker-cli admin user ls
woodpecker-cli lint .woodpecker/build-push-portal.yaml
```
Getting stuck on this:
```
-> % woodpecker-cli exec .woodpecker/build-push-portal.yaml
🔥 .woodpecker/build-push-portal.yaml has 2 errors:
   ❌ steps.build-and-push	Insufficient trust level to use `privileged` mode
   ❌ services.buildkitd	Insufficient trust level to use `privileged` mode
6:22PM FTL error running cli error="config has errors"
```
Eventhough I gave the project all the trusted checks.
It could be that its just not working very well...
---
Shifting to GH Actions and publishing my portal image in Docker Hub.
Widely accepted stack and flow.
GitHub Actions is getting stuck on building the image:
```
 > [build 8/8] RUN npm run build:
0.142 
0.142 > my-portal@0.0.1 build
0.142 > vite build
0.142 
0.146 sh: 1: vite: not found
``` 
Trying to simulate what the pipeline does:
```
docker buildx build -f Dockerfile .
```
This works.
Now running the pipeline using `act`, from repo root:
```
act --secret-file act.secrets workflow_dispatch
```
Act needs these secrets:
```
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
GITHUB_TOKEN
```
I can run it using `act`, and get the same error. So no closer to a solution.