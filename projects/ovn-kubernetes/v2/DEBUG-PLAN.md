# Plan: Debug TCP-only fails with ETP=Local + EgressService (OVN-K + MetalLB)

## Context

A LoadBalancer service with `externalTrafficPolicy: Local` + OVN `EgressService`
(`sourceIPBy: LoadBalancerIP`) on the k3s cluster behaves asymmetrically:

- **TCP + UDP on same port (8000):** TCP connection succeeds.
- **TCP only on the same port:** `nc -zv <VIP> 8000` hangs then times out.

Reproduction harness lives in `projects/ovn-kubernetes/v2/` (L2 mode, VIP
`192.168.2.120` — faster feedback loop than v3 BGP):
- `socat-metallb-tcp-udp.yaml` (**TCP+UDP** state — working)
- `socat-metallb-tcp-only.yaml` (**TCP-only** state — hangs)

**What we already know from prior investigation:**
- OVN NB database is byte-identical for TCP entries between the two states.
- Inbound DNAT fires in TCP-only: packets reach `group:14 → nat(dst=10.42.0.49:8000)` on GR_mbp (metadata=0x4).
- Pod replies hit the EgressService reroute (table=26) — 12 packets observed.
- TCP connection still times out — SYN-ACK never reaches the client.
- OVN-K creates **one LB per protocol** (TCP-only ⇒ 1 LB; TCP+UDP ⇒ 2 LBs).
- `reject=true` is set globally; empty-target LBs on non-endpoint nodes (mm1) send RST.
- **`externalTrafficPolicy: Cluster` does not reproduce** the hang — so
  ETP=Local is a necessary ingredient. ETP=Local is also a non-negotiable
  requirement of this deployment (source-IP preservation), so it stays in
  every Session 0 variant.

**Hypothesis to prove / disprove:**
The bug lives in OVS flow generation or conntrack-zone handling for the return
path when only a single-protocol LB exists. A second LB (UDP) on the same VIP:port
appears to incidentally rescue the TCP return path — likely by programming an
additional conntrack flow that keeps the reverse DNAT working.

**Key repos:**
- `/home/stan/Documents/ovn-kubernetes` (main branch OVN-K)
- `/home/stan/Documents/metallb` (MetalLB speaker)

**Key cluster facts:**
- Nodes: mm1 (192.168.2.60, control plane), mbp (192.168.2.11, worker, hosts pod)
- VyOS router: reachable as `ssh stan@vyos` (SSH key in `~/.ssh/`)
- **v2 VIP (active for debug): 192.168.2.120/32 (egress-pool, L2 mode, pinned to `brenp1s0f0` + `brens9`)**
- Pod IP: varies; fetch with `kubectl get pods -l app=socat-echo -o wide`
- mbp OVN pod: `ovnkube-node-*` on mbp (container: `ovnkube-controller`, `ovn-controller`)
- mm1 OVN pod: `ovnkube-node-*` on mm1
- External bridge on mbp: `brens9`, patch-port `patch-br-int-to-brens9_mbp` (OFPort 4)
- Metadata mapping on mbp br-int (will re-verify per session, can shift): historically 0x3 = node switch, 0x4 = GR_mbp, 0x5 = ext switch (brens9)
- DNAT group on mbp: `group:14` style → `nat(dst=<podIP>:8000)`

---

## Three-session structure

The plan is split into three sessions so context stays tight and each session
has a clear goal. Session 0 narrows scope; Session A's artifacts feed Session B.

### Session 0 — Isolation matrix (preflight)
**Goal:** Identify which of `EgressService` / `MetalLB` is actually required
to trigger the TCP-only hang. ETP=Local is fixed (necessary by prior data
and required by the deployment). Result sharpens Sessions A and B so we
trace only the relevant tables and read only the relevant code.

### Session A — Packet tracing (live cluster deep dive)
**Goal:** Prove exactly where the SYN-ACK is lost in TCP-only state, and
produce a per-step packet-path diff between the two states.

### Session B — Source code deep dive
**Goal:** Given Session A's findings, pinpoint the exact commit / function /
branch condition in OVN-K or MetalLB that causes the bug, and propose a fix.

A short shared artifact (`projects/ovn-kubernetes/v2/BUG-FINDINGS.md`) is
produced at the end of Session A and consumed at the start of Session B so
they don't need to re-derive context. It lives in the repo (not `/tmp`) so
a fresh Session B context can actually read it.

---

## Pre-approved commands (apply to all sessions)

I (Claude) may execute the following without further confirmation:

**Read-only cluster inspection:**
- `kubectl get / describe / logs / exec -- <read-only-cmd>` in any namespace
- `kubectl exec -n ovn-kubernetes <pod> -c <container> -- ovs-ofctl dump-flows/dump-groups/dump-ports-desc br-int/brens9`
- `kubectl exec -n ovn-kubernetes <pod> -c <container> -- ovs-vsctl show / list`
- `kubectl exec -n ovn-kubernetes <pod> -c <container> -- ovn-nbctl lb-list / find / show / get`
- `kubectl exec -n ovn-kubernetes <pod> -c <container> -- ovn-sbctl lflow-list / find`
- `kubectl exec -n ovn-kubernetes <pod> -c <container> -- ovn-trace …`
- `kubectl exec -n ovn-kubernetes <pod> -c <container> -- ovs-appctl ofproto/trace / dpctl/dump-conntrack / dpctl/dump-flows`
- `kubectl exec -n ovn-kubernetes <pod> -c <container> -- conntrack -L / -E`
- `kubectl exec <pod> -- tcpdump -nni any -c N` (bounded captures only)
- `ssh stan@vyos <read-only>` (`show ip route …`, `show arp …`, `show interfaces …`, `tcpdump -nni ethX -c N`)

**Test-flow toggling (mutates only the v2 socat manifests):**
- `kubectl apply -f projects/ovn-kubernetes/v2/socat-metallb-tcp-udp.yaml`
- `kubectl apply -f projects/ovn-kubernetes/v2/socat-metallb-tcp-only.yaml`
- `kubectl apply -f projects/ovn-kubernetes/v2/socat-no-egressservice-tcp-only.yaml` (Session 0 variant B)
- `kubectl apply -f projects/ovn-kubernetes/v2/socat-externalips-tcp-only.yaml` (Session 0 variant D)
- `kubectl delete svc socat-echo-service` (required when flipping the port set)
- `kubectl delete pod -l app=socat-echo` (to force IP churn if needed)
- `kubectl delete egressservice socat-echo-service` (Session 0 variant B cleanup)
- Creating the two new v2 variant manifests (`socat-no-egressservice-tcp-only.yaml`, `socat-externalips-tcp-only.yaml`) during Session 0
- Running `nc`, `nc -u`, `curl`, `ping` from host against the VIP (192.168.2.120 for A/B; 192.168.2.121 for D)

**Code reading:**
- Anything under `/home/stan/Documents/ovn-kubernetes/**` and `/home/stan/Documents/metallb/**` (Read/Grep/Glob only)
- `git log`, `git blame`, `git show` in those repos

**Not pre-approved (still require confirmation):**
- Modifying cluster config beyond the socat manifests (e.g. OVN-K Helm values, MetalLB CRs)
- `git push`, PR creation, `helm upgrade`, ConfigMap edits, restarting ovnkube pods
- Anything on VyOS that isn't `show …` — **specifically including the Session 0 variant D static route (`set protocols static route 192.168.2.121/32 next-hop 192.168.2.11` + commit/save)**. I will pause and ask before applying.
- Writing code patches to the OVN-K / MetalLB repos

---

## Session 0 — Isolation matrix

**Goal:** Determine whether `EgressService` and/or `MetalLB` are required to
trigger the TCP-only hang. ETP=Local is fixed in every variant (necessary
by prior data and deployment requirement).

### 0.1 Variants

| # | Variant | MetalLB | ETP | EgressService | Manifest |
|---|---|---|---|---|---|
| A | Baseline (current failing repro) | yes | Local | yes | `socat-metallb-tcp-only.yaml` |
| B | Drop EgressService | yes | Local | no | `socat-no-egressservice-tcp-only.yaml` (new — copy of A with the `EgressService` CR removed) |
| D | Drop MetalLB | no | Local | yes | `socat-externalips-tcp-only.yaml` (new — `spec.externalIPs: [192.168.2.121]` instead of `type: LoadBalancer` + MetalLB pool/L2Advertisement; Service still references EgressService via name) |

Note on variant D: `EgressService.sourceIPBy: LoadBalancerIP` may require an
actual LoadBalancer-allocated ingress IP to work. If OVN-K rejects the
EgressService without MetalLB allocating an IP, record that as the
outcome of D and treat D as inconclusive for bug reproduction (it tells
us EgressService+MetalLB are coupled, not whether the bug needs MetalLB
per se). A D' fallback uses `sourceIPBy: Network` — note the substitution
in the result block if used.

### 0.2 Procedure

For each variant in sequence:

1. `kubectl delete svc socat-echo-service --ignore-not-found`
2. `kubectl delete egressservice socat-echo-service --ignore-not-found` (defensive, for variant transitions)
3. For variant D only: apply VyOS static route (**pause for user confirmation first**):
   ```
   ssh stan@vyos
   configure
   set protocols static route 192.168.2.121/32 next-hop 192.168.2.11
   commit; save; exit
   ```
4. `kubectl apply -f projects/ovn-kubernetes/v2/<manifest>`
5. Wait for Service to get an IP (`kubectl get svc socat-echo-service -w`, ≤20s).
6. Sanity: `arping -c 2 <VIP>` from a host on 192.168.2.0/24 (A/B use `.120`; D uses `.121` via route, arping will not show the MAC but `ip route get` will).
7. Fire test: `for i in 1 2 3 4 5; do nc -zv <VIP> 8000; done`
8. Record pass (all 5 succeed quickly) or fail (any hang >5s).

After variant D: remove the static route (`delete protocols static route 192.168.2.121/32`, commit, save).

### 0.3 Decision tree

Baseline A is expected to fail. The B/D outcomes select Session A/B scope:

| A | B | D | Conclusion | Session A/B scope |
|---|---|---|---|---|
| fail | fail | fail | EgressService and MetalLB both red herrings; bug is in the ETP=Local LB pipeline itself | A: trace plain ETP=Local + single-proto LB. B: read `buildPerNodeLBs` ETP=Local branches + `noSNATRouterRules` |
| fail | pass | fail | EgressService required; MetalLB not required | A: focus on table 26 + return path. B: deep-dive `egressservice_zone_service.go` + LRP generation |
| fail | fail | pass | MetalLB required — unexpected | A: capture MetalLB speaker + ARP/L2 flow. B: read `speaker/layer2_controller.go` |
| fail | pass | pass | Joint trigger (EgressService + MetalLB both required) | A: trace their interaction. B: read how EgressService gates on MetalLB-allocated IP |
| fail | pass | inconclusive (D' needed) | At minimum EgressService is required; MetalLB coupling unknown | A: as "EgressService required" row. B: add check on EgressService validation against Service.Status.LoadBalancer |

### 0.4 Session 0 deliverable

Append a short result block to this file (below the decision tree, under a
`## Session 0 results (run YYYY-MM-DD)` heading) recording:
- Per-variant pass/fail verdict and raw `nc -zv` output timing.
- The selected row from the decision tree.
- The scoped Session A focus tables and Session B focus files.

---

## Session A — Packet Tracing

### A.1 Stable reproduction harness

The two v2 manifests already match their filenames (verified 2026-04-22):
- `socat-metallb-tcp-udp.yaml` → Service exposes TCP **and** UDP on 8000
- `socat-metallb-tcp-only.yaml` → Service exposes TCP **only** on 8000

Both files keep both socat containers (TCP listener + UDP listener) so the
pod is identical across flips — only the Service port set changes. That
isolates the variable to OVN-K's LB generation path.

Flip procedure (≤30s):
```bash
kubectl delete svc socat-echo-service --ignore-not-found
kubectl apply -f projects/ovn-kubernetes/v2/socat-metallb-<state>.yaml
```

(`delete svc + apply` is required: `kubectl apply` silently drops the second
port entry when a mixed-protocol service shares a port number.)

Sanity check after each flip:
- `kubectl get svc socat-echo-service` shows expected ports
- `kubectl get endpointslices | grep socat` shows endpoints for the right protocols
- From a host on 192.168.2.0/24: `arping -c 2 192.168.2.120` shows mbp's MAC
  (confirms MetalLB L2 speaker on mbp owns the VIP)

### A.2 Three-layer tcpdump (per state)

Run simultaneously, then trigger `nc -zv 192.168.2.120 8000` from the host:

| Layer | Command | What it proves |
|---|---|---|
| VyOS LAN edge | `ssh stan@vyos 'sudo tcpdump -nni <lan-if> host 192.168.2.120 and tcp port 8000 -c 40'` (interface discovered via `show interfaces`) | SYN transits router (if client is off-LAN); SYN-ACK return |
| Node NIC (mbp) | `kubectl exec -n ovn-kubernetes <mbp-ovnkube-pod> -c ovn-controller -- tcpdump -nni ens9 'tcp port 8000' -c 40` | SYN reaches mbp; SYN-ACK leaves mbp |
| Pod veth (pod) | `kubectl exec <pod> -- tcpdump -nni eth0 'tcp port 8000' -c 40` | SYN reaches pod; pod sends SYN-ACK |

Note: in L2 mode, if the test client is on 192.168.2.0/24 the client ARPs
192.168.2.120 directly and VyOS doesn't see the traffic. Test from a host on
192.168.2.0/24 for the simplest path; test from off-subnet only if we want to
confirm VyOS routing is not implicated.

Expected in **State B (fail)**: SYN arrives at all three layers; SYN-ACK leaves
the pod but never egresses ens9. If that's the case, the drop is between pod
veth and ens9 — i.e., inside OVN's br-int pipeline.

### A.3 OVS flow-counter diff

For both states, capture:
```
ovs-ofctl dump-flows br-int > /tmp/flows-$STATE.txt
ovs-ofctl dump-groups br-int > /tmp/groups-$STATE.txt
```

Then fire 5 `nc -zv` attempts and recapture. Diff the two captures within each
state to see which flows incremented, then diff State A vs State B to see which
flows exist in A but not B (or vice versa).

Focus areas for the diff (prune per Session 0's decision tree):
- Table 15 (DNAT zone), metadata=0x4 — inbound conntrack
- Table 16 (post-CT) — does reply un-DNAT
- Table 18 (LB group dispatch), metadata=0x4
- Table 22/23 (reverse-path), metadata=0x3 — is there a return flow for the VIP?
- Table 26 (EgressService reroute) — **drop this row if Session 0 exonerates EgressService**
- Table 44 (egress ACL)
- Any flow referencing `reject` action

### A.4 ovn-trace + ofproto/trace (symbolic packet walk)

Run `ovn-trace` on mbp's sbctl for both directions, both states:

**Inbound (client → VIP):**
```
ovn-trace --ct new mbp \
  'inport == "<ext-lsp>" && eth.src == <client-mac> && eth.dst == <mbp-ext-mac> \
   && ip4.src == <client-ip> && ip4.dst == 192.168.2.120 \
   && ip.ttl == 64 && tcp && tcp.src == 54321 && tcp.dst == 8000'
```

**Outbound reply (pod → client):**
```
ovn-trace --ct est mbp \
  'inport == "<pod-lsp-name>" && eth.src == <pod-mac> && eth.dst == <pod-gw-mac> \
   && ip4.src == <pod-ip> && ip4.dst == <client-ip> \
   && ip.ttl == 64 && tcp && tcp.src == 8000 && tcp.dst == 54321'
```

Then feed the same micro-flow to `ovs-appctl ofproto/trace br-int <flow>` for a
table-by-table walk. Compare per-table outputs between State A and State B.

### A.5 Conntrack inspection

While a connection attempt is in flight (before the timeout), dump live CT:
```
ovs-appctl dpctl/dump-conntrack | grep -E '192.168.2.120|<pod-ip>'
conntrack -L 2>/dev/null | grep -E '192.168.2.120|<pod-ip>'
```

Compare zones. Prior work identified zone 11 (REG11) for DNAT and zone 13
(REG13) for SNAT. Look for:
- Whether State A has a second CT entry (UDP) that somehow affects TCP reverse
  flow lookups (shared expectations / master-CT coupling).
- Whether `ct_mark` bits (especially bit 2 set by group:14) survive the return path.

### A.6 Session A deliverable: `projects/ovn-kubernetes/v2/BUG-FINDINGS.md`

Produce a short written artifact with:
1. Confirmed answer: *where exactly* the packet is dropped (inbound vs return path, which table).
2. Flow diff: the specific OVS flows that exist in State A but not in State B (and vice versa).
3. CT diff: the specific CT entries / zones present in A that are missing in B.
4. ovn-trace output for both directions in both states.
5. A proposed narrow hypothesis for Session B (e.g. "missing reverse-DNAT flow in table=22 metadata=0x4 when only one LB exists for the VIP:port tuple").

This file lives in the repo (committed) so Session B — starting from a fresh
context — can actually read it. Raw scratch (`/tmp/flows-*.txt` etc.) stays in
`/tmp`; only the distilled findings land in the repo.

---

## Session B — Source Code Deep Dive

**Input:** `projects/ovn-kubernetes/v2/BUG-FINDINGS.md` from Session A.
Session B starts by reading this file before touching any source repo.

Scope is pruned by Session 0's decision tree — don't read
`egressservice_zone_service.go` if variant B passed; don't read `speaker/*.go`
if variant D didn't implicate MetalLB.

### B.1 OVN-Kubernetes LB generation

Critical files (confirmed to exist via earlier mapping):
- `go-controller/pkg/ovn/controller/services/lb_config.go`
  - `buildServiceLBConfigs()` line 133 — protocol bucketing
  - `configsByProto()` line 768 — how configs are split by TCP/UDP/SCTP
  - `buildClusterLBs()` line 256, loop at line 283 — per-protocol LB creation
  - `buildPerNodeLBs()` line 600, protocol loop line 608 — per-node (GR) LB creation
  - Line 657 — `masqueradeVIP` only for NodePort (not pure LoadBalancer) — potential suspect
  - Line 700 — `noSNATRouterRules` when `externalTrafficLocal && len(targets) > 0`
  - `mergeLBs()` line 840 — `canMergeLB()` blocks cross-protocol merges
  - `lbOpts()` line 794, line 800 — `Reject = true`
  - `makeLBName()` line 243 — LB names include protocol
- `go-controller/pkg/ovn/controller/services/loadbalancer.go`
  - `buildLB()` line 340 — OVN LB record construction, reject options 347–349
- `go-controller/pkg/util/util.go`
  - `GetEndpointsForService()` line 804 — keyed by `protocol/portname`
  - `GetServicePortKey()` line 680

Questions to answer by reading:
1. Is there a conditional that emits an extra per-node rule/flow only when
   multiple protocols share a VIP:port? (Grep for `len(protos)`, `TCP && UDP`, per-port set ops.)
2. Does `noSNATRouterRules` / `skip_snat` generation differ between 1-LB and 2-LB states?
3. Does the EgressService controller interact with LBs through any per-protocol loop
   that quietly fans out shared flows?

### B.2 OVN-K EgressService zone service

(Skip this subsection if Session 0 variant B passed.)

- `go-controller/pkg/ovn/controller/egressservice/egressservice_zone_service.go`
  - `createOrUpdateLogicalRouterPoliciesOps()` line 237 — LRP creation
    (`ip4.src == podIP → reroute → mgmtIP`, priority 101)
  - `allEndpointsFor()` line 136 — IPv4/IPv6 grouping (no per-protocol filter)
  - `syncEgressService()` line ~354 — invocation order

Grep for places where `svc.Spec.Ports` or `Protocol` is read and affects which
LRPs / NB entries are written.

### B.3 OVN NB → OVS flow translation (ovn-northd + ovn-controller)

Scope: read, do not modify.

OVN-K only writes NB. The NB→SB→flows translation is in OVN itself (not in
the OVN-K repo). If Session A shows that NB is identical between A and B but
flows differ, the asymmetry is born inside `ovn-northd` or `ovn-controller`.
In that case I'll:
1. Dump SB `Logical_Flow` table for both states and diff them.
2. If the SB lflows differ, the bug is in ovn-northd's LB lflow generator
   (typically `northd/lb.c`, `northd/northd.c`); note it and stop — fixing OVN
   upstream is out of scope.
3. If SB is identical but OVS flows differ, the bug is in ovn-controller's
   physical-flow engine (`controller/lflow.c`, `controller/physical.c`).

### B.4 MetalLB path

(Skip this subsection unless Session 0 variant D failed, implicating MetalLB.)

Lower priority — MetalLB is already confirmed to behave identically per-protocol
at the speaker level, and the asymmetry lives inside OVN once traffic arrives
at the node. Still verify:
- `speaker/layer2_controller.go` — L2 advertisement path (current v2 mode)
- `speaker/bgp_controller.go` — BGP advertisement doesn't gate on port protocol (v3 mode context)
- `speaker/main.go` `SetBalancer()` line 370 — per-service, not per-protocol

### B.5 Session B deliverable

A short written report:
1. Exact function(s) / line(s) containing the faulty branch.
2. Whether the bug is in OVN-K, ovn-northd, ovn-controller, or MetalLB.
3. Proposed minimal fix (patch sketch) or upstream bug-report outline.
4. Any workaround we can apply in the meantime at the YAML level.

---

## Files the debug process may produce

**In-repo (committed):**
- `projects/ovn-kubernetes/v2/BUG-FINDINGS.md` — Session A distilled findings (handoff to Session B)
- `projects/ovn-kubernetes/v2/socat-no-egressservice-tcp-only.yaml` — Session 0 variant B harness
- `projects/ovn-kubernetes/v2/socat-externalips-tcp-only.yaml` — Session 0 variant D harness
- Session 0 results block appended to this file

**Scratch (`/tmp/`, not committed):**
- `/tmp/flows-{A,B}.txt`, `/tmp/groups-{A,B}.txt`, `/tmp/ct-{A,B}.txt`, `/tmp/ovn-trace-{A,B}-{in,out}.txt` — raw captures

The only existing repo files this process may edit are the v2 socat
manifests (to correct typos or add variants) and this plan file (to
record Session 0 results), all only if the user explicitly requests it.

---

## Verification that the plan worked

We will know the debug sessions have succeeded when:
1. Session 0's matrix completes with a clear per-variant pass/fail verdict
   recorded in this file, and Session A/B scope has been narrowed accordingly.
2. A single, specific OVS/OVN artifact (flow, CT entry, lflow, or NB row) is
   identified as missing/present in the failing state vs the working state.
3. That artifact is traced to a specific branch in a specific function in one
   of the three code bases (OVN-K, OVN, MetalLB).
4. A minimal yaml-level workaround is documented, even if the proper fix is upstream.
