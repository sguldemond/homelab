# Woodpecker

[Woodpecker](https://woodpecker-ci.org/) is an alternative to GitHub Actions and can run on my cluster.

After setting up Woodpecker with GitHub OAuth integration, I ran into issues with privileged mode permissions that prevented running Docker builds.

The setup journey included:
- Installing via Helm chart
- Configuring GitHub OAuth
- Setting up custom Ingress
- Enabling open registration
- Attempting to configure privileged mode access

But ultimately the blocker with privileged mode permissions could not be resolved despite trying multiple approaches documented in the journey.
