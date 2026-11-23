# Beacon of Release — Runbook

A Java 17 Spring Boot service delivered by a Terraform-built lab: Jenkins on Kubernetes builds, tests and scans it,
publishes it to Docker Hub by commit, and promotes the exact digest through a GitOps repository that ArgoCD
reconciles. Prometheus, Grafana and Loki watch it. Everything below can be rebuilt from this repository, the
`beacon-gitops` repository, and two tokens.

Status: Chapters 1–4, the Final Trial, the optional GitOps expedition, and an observability stack — all done.

| URL (after bootstrap) | What | Login |
|---|---|---|
| http://beacon.127.0.0.1.nip.io | the application (`hello <name>`, `/actuator/health`) | — |
| http://jenkins.127.0.0.1.nip.io/job/beacon/ | pipeline | `admin` / `jenkins/jenkins-admin` Secret |
| http://argocd.127.0.0.1.nip.io | GitOps controller | `admin` / `argocd/argocd-initial-admin-secret` |
| http://grafana.127.0.0.1.nip.io/d/beacon | Beacon dashboard (metrics + logs) | `admin` / `monitoring/grafana-admin` Secret |

Copy any password to the clipboard without printing it:
```bash
kubectl get secret jenkins-admin -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d | pbcopy
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d | pbcopy
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d | pbcopy
```

## Architecture

```
Mac (Docker Desktop, 8 GB) ── 127.0.0.1:80/443 ──► Kind cluster "beacon"   (scripts/cluster-up.sh, outside Terraform)
                                                     ├─ control-plane   NodePorts 30080/30443 → Traefik
                                                     ├─ beacon-worker   workload=apps
                                                     └─ beacon-worker2  workload=builds, taint dedicated=builds:NoSchedule
Terraform owns everything inside the cluster:
  ns traefik         restricted   Traefik (NodePort, publishes 127.0.0.1 as the Ingress address)
  ns jenkins         restricted   Jenkins controller (JCasC, 79 pinned plugins), PVC jenkins-home, secrets
  ns jenkins-agents  privileged   ephemeral build pods (DinD) on the builds node only; PVC trivy-cache
  ns argocd          restricted   ArgoCD (lean), AppProject + Application "beacon"
  ns beacon          restricted   the application — synced by ArgoCD as service account beacon/argocd-sync
  ns monitoring      restricted   Prometheus, Grafana, kube-state-metrics, Loki, Alloy

Release flow
  git push (this repo) ─► Jenkins polls (2 min)
     build pod: 1 checkout ─► 2 docker build + tests ─► 3 Trivy scan ─► 4 push :<sha>, read @sha256
     promote pod: 5 commit digest to beacon-gitops ─► wait for ArgoCD Synced+Healthy ─► smoke test via Traefik
                  failure ─► git revert that commit ─► ArgoCD restores previous digest ─► build FAILS
  ArgoCD: watches beacon-gitops/apps/beacon every 60 s, prune + self-heal
  Prometheus scrapes beacon /actuator/prometheus, Traefik, kubelet, kube-state-metrics; Alloy ships pod logs to Loki
```

**Boundary.** The Kind cluster is a local prerequisite. Terraform never creates the cluster it connects to, so
`terraform plan` works on a clean machine. No cloud infrastructure is used.

## Repository map

| Path | Contents |
|---|---|
| `src/`, `pom.xml` | the application; tests cover greeting, health, metrics exposure, and that `/actuator/env`, `/heapdump`, `/metrics` stay closed |
| `Dockerfile`, `.dockerignore` | multi-stage build; tests run inside `docker build` |
| `Jenkinsfile` | the pipeline (Kubernetes agents, 5 stages) |
| `cluster/kind-config.yaml` | 3-node cluster, pinned node image, port mappings, build-node taint |
| `terraform/` | everything in the cluster: `namespaces.tf`, `rbac.tf`, `secrets.tf`, `storage.tf`, `traefik.tf`, `jenkins.tf`, `argocd.tf`, `monitoring.tf`; chart values in `values/`; `jenkins-plugins.txt`; `dashboards/beacon.json`; `.terraform.lock.hcl`; `terraform.tfvars.example` |
| `scripts/` | `bootstrap.sh`, `teardown.sh`, `cluster-up.sh`, `secrets-env.sh`, `scan.sh`, `smoke-test.sh`, `gitops-seed.sh`, `gitops-promote.sh`, `resolve-jenkins-plugins.py` |
| `docs/evidence/` | scan reports, RBAC checks, Chapter 3 and 4 verification, GitOps and observability evidence |
| **`beacon-gitops`** repo | `apps/beacon/` — ConfigMap, Deployment, Service, Ingress and `kustomization.yaml` pinning the image digest |

## Prerequisites

| Tool | Version used |
|---|---|
| macOS (Apple Silicon, arm64) | 27.0.1 |
| Docker Desktop (engine) — 8 GB memory, 4 GB swap recommended | 29.5.3 |
| kind | v0.33.0 (node image `kindest/node:v1.37.0`, pinned by digest) |
| kubectl / helm / terraform | v1.36.2 / v4.2.1 / v1.16.4 |
| trivy (local scans only) | 0.76.2 |
| python3, openssl, curl, git | any recent |

```bash
brew install kind kubectl helm terraform trivy
```

Accounts (once):

| What | Setting |
|---|---|
| Docker Hub repository `<user>/beacon` | **public** (Kind pulls without credentials) |
| Docker Hub access token | Read & Write |
| GitHub repository `beacon-gitops` | public (ArgoCD reads anonymously) |
| GitHub fine-grained token | only `beacon-gitops`, **Contents: Read and write**, nothing else |

## Bootstrap from zero

1. Inputs (non-secret):
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```
   Set `git_repo_url`, `dockerhub_username`, `gitops_repo_url` (and `git_branch` if not `main`).

2. One command:
   ```bash
   ./scripts/bootstrap.sh
   ```
   It checks the prerequisites, creates the cluster, loads secrets (prompting only for the two tokens on a fresh
   cluster), runs `terraform init` and `plan`, **waits for your review**, applies (about 10 minutes), checks that a
   second plan shows no changes, checks Jenkins, ArgoCD and Grafana answer HTTP 200, reports the ArgoCD application
   state, and queues the first Jenkins build (SCM polling only starts after one build).

3. Only if `beacon-gitops` is empty (first time ever; it survives teardown): seed it with a published digest, then
   ArgoCD syncs within a minute.
   ```bash
   source scripts/secrets-env.sh && ./scripts/gitops-seed.sh https://github.com/<user>/beacon-gitops.git docker.io/<user>/beacon@sha256:<digest>
   ```

Hostname resolution: `*.127.0.0.1.nip.io` is public wildcard DNS for `127.0.0.1`; no `/etc/hosts` edits.
Offline: add `127.0.0.1 jenkins.127.0.0.1.nip.io argocd.127.0.0.1.nip.io grafana.127.0.0.1.nip.io beacon.127.0.0.1.nip.io` to `/etc/hosts`.

## Credentials and secrets

| Secret | Source | Lives in | Used by |
|---|---|---|---|
| Docker Hub token | you, hidden prompt | `jenkins/dockerhub` | Jenkins credential `dockerhub` (push) |
| GitHub token | you, hidden prompt | `jenkins/gitops` | Jenkins credential `gitops` (commit digests) |
| Jenkins admin password | generated (`openssl rand`) | `jenkins/jenkins-admin` | Jenkins login |
| Grafana admin password | generated | `monitoring/grafana-admin` | Grafana login |
| ArgoCD admin password | generated by ArgoCD | `argocd/argocd-initial-admin-secret` | ArgoCD login |

- `source scripts/secrets-env.sh` exports them as `TF_VAR_*` for the current shell. It reads existing values back from
  the cluster, so you are prompted only on a fresh cluster. Run it in every new terminal before Terraform.
- Terraform takes them as **ephemeral variables** and writes them through **write-only attributes** (`data_wo`): never
  in Git, `terraform.tfvars`, plan files, outputs or state. Verified: `grep -c "$TF_VAR_dockerhub_token" terraform/terraform.tfstate` → `0`.
- Jenkins encrypts credentials at rest; the pipeline masks them in logs; `docker login` uses `--password-stdin`; the
  GitHub token reaches git through a credential helper, never in a URL.
- **Rotate:** export the new value, set `secrets_revision = <n+1>` in `terraform.tfvars`, plan, apply, then restart the
  consumer (`kubectl rollout restart statefulset/jenkins -n jenkins`). Exercised once (revision 2).
- The cluster holds the only copy of the tokens: keep them in a password manager. Delete unused tokens.

## Terraform state

- Local backend `terraform/terraform.tfstate`, gitignored, `chmod 600`. It holds no secret values (above) but maps the
  infrastructure. Saved plans (`tfplan`) are gitignored too.
- For a team: remote backend with encryption at rest, state locking and restricted access (S3 + DynamoDB lock,
  Terraform Cloud, or equivalent).
- All provider and chart versions are pinned; `.terraform.lock.hcl` covers darwin/linux on arm64/amd64.

## Security design

**Pod Security Admission.** `restricted` in every namespace except `jenkins-agents` (`privileged`, for DinD), all with
`warn`/`audit` at `restricted`. Every chart was rendered and dry-run against the namespace before install; two gaps
were fixed that way (Jenkins `runAsNonRoot`, Loki `seccompProfile`). Node-exporter and host-path log collection were
left out on purpose because they need host access.

**DinD containment.** Privileged only in `jenkins-agents`; agent pods schedule only on the tainted `builds` node; the
Docker socket is a pod-local `emptyDir`, never TCP; image storage is deleted with the pod; build pods run as
`jenkins-agent` with no API token. Residual risk: a privileged container can escape to `beacon-worker2`. Rootless
BuildKit would remove it.

**RBAC** — our own grants are namespaced Roles only; nothing is bound to cluster-admin.

| Service account | Allowed | Not allowed |
|---|---|---|
| `jenkins/jenkins` (controller) | pods, exec, logs in `jenkins-agents`; read ConfigMaps in `jenkins` (JCasC reload) | anything in `beacon`, secrets |
| `jenkins-agents/jenkins-agent` (build pods) | nothing (no token) | everything |
| `jenkins-agents/beacon-deployer` (promote pods) | **read-only** in `beacon`; get/watch the `beacon` Application only | any write to the cluster |
| `beacon/argocd-sync` (ArgoCD sync identity, impersonation) | create/update/delete Deployments, Services, ConfigMaps, Ingresses in `beacon` | other kinds, other namespaces, secrets |

**ArgoCD boundary.** AppProject `beacon`: source only `beacon-gitops`, destination only `beacon`, only those four kinds,
no cluster-scoped resources, syncs impersonate `beacon/argocd-sync`. A malicious GitOps commit cannot leave the
namespace. `exec` is disabled; the repo-server accepts connections only from ArgoCD components (chart NetworkPolicy).

**Cluster-wide chart roles (accepted, read-mostly).** Traefik (watch Ingresses/Services/EndpointSlices/Secrets for TLS,
update `ingresses/status`), the ArgoCD application controller (read everything, write only via impersonation for this
app), Prometheus and kube-state-metrics (read), Alloy (read pods and pod logs).

Evidence: [docs/evidence/rbac-can-i.txt](docs/evidence/rbac-can-i.txt); a root pod in `beacon` is rejected with
`violates PodSecurity "restricted:latest"`.

## Image and scan (Chapter 1)

- [Dockerfile](Dockerfile): Maven build and tests inside `docker build`; `--target test-results` exports reports even when
  tests fail; the `verified` stage fails the build on any test failure.
- Runtime: `alpine:3.24.2` + Alpine `openjdk17-jre-headless`, UID 10001, read-only root filesystem, writable `/tmp`.
- `scripts/scan.sh <image> [out]`: Trivy OS + Java libraries, `--exit-code 1`, 15-minute timeout, JSON report, image ID,
  scanner and DB version. Any finding or scanner error is a non-zero exit. No ignore lists, no `--ignore-unfixed`.

```bash
docker build --target test-results --output type=local,dest=reports/tests .
docker build -t beacon:dev . && ./scripts/scan.sh beacon:dev
docker run --rm -d --name beacon -p 8080:8080 --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges -e YOUR_NAME=you beacon:dev
```

## Jenkins as code (Chapter 2)

[terraform/values/jenkins.yaml.tftpl](terraform/values/jenkins.yaml.tftpl): chart 5.13.3, `jenkins/jenkins:2.580.2-jdk25`,
0 controller executors, admin from a Secret (no wizard), Kubernetes cloud (`jenkins-agents`, `jenkins-agent`, builds node),
credentials `dockerhub` and `gitops` from mounted Secrets, global variables (`IMAGE_REPO`, `GITOPS_*`, `ARGOCD_*`,
`APP_HOSTNAME`, `INGRESS_URL`), and job `beacon` created by Job DSL (Jenkinsfile from `git_branch`, polling every 2 min).

[terraform/jenkins-plugins.txt](terraform/jenkins-plugins.txt) pins the full dependency tree (79 plugins). Upgrade:
change `jenkins_image_tag`, then regenerate and review the diff:
```bash
python3 scripts/resolve-jenkins-plugins.py <core-version> terraform/jenkins-plugins.txt
```

## Kubernetes manifests (Chapter 3)

They live in **`beacon-gitops/apps/beacon/`** (moved there for the GitOps expedition; their history is in PR #3 of this
repo). 2 replicas on the apps node; rolling update with `maxUnavailable: 0`; startup, readiness
(`/actuator/health/readiness`) and liveness probes; requests 100m/256Mi, limits 500m/512Mi; non-root UID 10001, no
privilege escalation, all capabilities dropped, seccomp, read-only root filesystem with an `emptyDir` on `/tmp`, no
service account token; `preStop` sleep so Traefik drains; `YOUR_NAME` from a ConfigMap; ClusterIP Service; Ingress
class `traefik`; image pinned by digest in `kustomization.yaml`.

Change the greeting: edit `YOUR_NAME` in `apps/beacon/configmap.yaml` in `beacon-gitops`, commit, then
`kubectl rollout restart deployment/beacon -n beacon` (env is read at start-up).

## Pipeline (Chapter 4 + GitOps)

| # | Stage | Pod / container | Fails closed on |
|---|---|---|---|
| 1 | Checkout, print commit, stash scripts | build / `jnlp` | — |
| 2 | `docker build` with tests; reports exported first and recorded by `junit` even on failure | build / `docker` → DinD | any test failure |
| 3 | `scan.sh`; archives `trivy.json`, `trivy-version.json` (version, DB `UpdatedAt`), `image-id.txt`; DB cached on PVC `trivy-cache` | build / `trivy` | any finding or scanner error |
| 4 | push `IMAGE_REPO:<12-char sha>`, read `@sha256` digest | build / `docker` | login or push error |
| 5 | `gitops-promote.sh`: commit digest to `beacon-gitops`, wait (≤ 5 min) for ArgoCD `Synced`+`Healthy` at that commit, smoke test through Traefik; on failure `git revert` its own commit, wait for recovery, fail the build. Always archive `release.json` | promote / `kubectl` | sync timeout, `Degraded`, smoke failure |

No overlapping deployments: `disableConcurrentBuilds()` plus `lock('beacon-production')`. Polling builds only the newest
commit; after changing `git_branch`, one build is needed before polling follows the new branch.

Gate evidence: [docs/evidence/ch4-pipeline.md](docs/evidence/ch4-pipeline.md) — failing test (#4), Log4Shell (#6), broken
readiness probe rolled back (#10), digest scanned = recorded = running (#11). GitOps promotions: builds #14 and #15.

## GitOps with ArgoCD

- Deploy = a commit in `beacon-gitops` by `beacon-ci`; `git log` there is the deployment history.
- **Roll back:** in `beacon-gitops`, `git revert <deploy-commit> && git push`; ArgoCD syncs the previous digest within
  about a minute. The pipeline does the same automatically when a promotion fails.
- **Drift correction:** manual changes are undone by self-heal. Check it:
  `kubectl scale deploy/beacon -n beacon --replicas=5` then `kubectl get deploy beacon -n beacon -w` → back to 2.
- **Status:** `kubectl get application beacon -n argocd`, or the ArgoCD UI.
- Taking over the existing workload did not restart pods (the manifests matched the live state).

## Observability

| Component | Chart | Lean settings |
|---|---|---|
| Prometheus, operator, kube-state-metrics | kube-prometheus-stack 93.9.0 | 2 d retention (2 GB cap), 30 s scrape, no Alertmanager, no node-exporter |
| Grafana 13.3.1 | grafana-community 14.5.0 (bundled) | admin from Secret, dashboards and datasources from code, no sign-up or anonymous access |
| Loki 3.6 | loki 7.7.0 | single binary, filesystem, 72 h retention, caches and canary off |
| Alloy 1.22 | alloy 1.16.0 | one Deployment tailing pod logs through the Kubernetes API (no hostPath, non-root) |

- The app exposes `/actuator/prometheus` (Micrometer, latency histograms); only `health` and `prometheus` are exposed.
- **Beacon dashboard** ([terraform/dashboards/beacon.json](terraform/dashboards/beacon.json), 13 panels): replicas, request rate,
  5xx ratio, restarts, requests by URI/status, latency p50/p95/p99, JVM heap, CPU, Traefik requests by code, running
  image digest, Traefik access log for the Beacon route, app logs, Jenkins/ArgoCD logs.
- **Alerts** (visible in Prometheus and Grafana): `BeaconDown`, `BeaconHighErrorRate` (> 5 % 5xx), `BeaconPodRestarting`.
  `BeaconDown` fired while the running image had no metrics endpoint and resolved when build #15 shipped it.

Evidence: [docs/evidence/observability/verification.txt](docs/evidence/observability/verification.txt).

## Operations

| Task | How |
|---|---|
| Release | push to `git_branch`; watch the job |
| Roll back | `git revert` the deploy commit in `beacon-gitops` |
| Inspect a release | Jenkins build → `release.json` (commit, digest, GitOps commit, previous image, Trivy version and DB time, result) |
| Rotate a secret | export new value, bump `secrets_revision`, plan, apply, restart consumer |
| Upgrade Jenkins | bump `jenkins_image_tag`, regenerate `jenkins-plugins.txt`, plan, apply |
| Upgrade a chart | bump its `*_chart_version`, render + dry-run, plan, apply, second plan |
| Rescan an image | `./scripts/scan.sh <image>` (a clean scan is one DB snapshot, not a permanent guarantee) |

## Verification evidence

| Claim | Evidence |
|---|---|
| Image clean; scan gate fails closed | [beacon-dev-trivy.json](docs/evidence/beacon-dev-trivy.json) 0 findings; [gate-test-alpine-3.18.0.json](docs/evidence/gate-test-alpine-3.18.0.json) 49 findings → exit 1; missing image → exit 1; scanner timeout (build #13) → stopped |
| Least privilege | [rbac-can-i.txt](docs/evidence/rbac-can-i.txt); ArgoCD syncs as `beacon/argocd-sync` ([argocd-sync-impersonation.txt](docs/evidence/gitops/argocd-sync-impersonation.txt)) |
| Reproducible infrastructure | full teardown and rebuild from zero (18 resources then; 34 with ArgoCD and monitoring), second plan `exit 0` after every apply |
| Jenkins from code | job, credentials, cloud and 79 plugins created with no clicks; 0 plugin load errors |
| Workload resilience | [ch3-verification.txt](docs/evidence/ch3-verification.txt): pod deleted under load 104/104 OK; failed rollout rolled back under load 189/189 OK |
| Pipeline gates and exact digest | [ch4-pipeline.md](docs/evidence/ch4-pipeline.md) |
| GitOps promotion | [gitops-repo-log.txt](docs/evidence/gitops/gitops-repo-log.txt), [build14-release.json](docs/evidence/gitops/build14-release.json), [build15-release.json](docs/evidence/gitops/build15-release.json), [argocd-application.json](docs/evidence/gitops/argocd-application.json) |
| Observability | [verification.txt](docs/evidence/observability/verification.txt), [beacon-dashboard-panels.json](docs/evidence/observability/beacon-dashboard-panels.json) |

## Teardown

```bash
./scripts/teardown.sh
```
Deletes the ArgoCD Application first (so its finalizer runs while ArgoCD is alive), then `terraform destroy`. Keeps the cluster.

```bash
./scripts/teardown.sh --all
```
Also deletes the Kind cluster.

| Data | `teardown.sh` | `--all` |
|---|---|---|
| This repository, `beacon-gitops` (desired state + deploy history), Docker Hub images | kept | kept |
| `terraform/terraform.tfvars`; tokens in your password manager | kept | kept |
| Kind cluster | kept | deleted |
| Jenkins home (build history, artifacts), Prometheus TSDB, Loki chunks, Trivy cache | deleted (reclaim policy `Delete`) | deleted |
| In-cluster secrets | deleted | deleted |

Configuration comes back identically from code; only history and metrics are lost. `helm uninstall jenkins -n jenkins`
alone keeps `jenkins-home`, because Terraform owns that PVC.

## Known limitations

- arm64 only (Apple Silicon host, arm64 Kind nodes).
- Local Terraform state, single operator; Jenkins and ArgoCD poll (no webhooks reach a laptop).
- `jenkins-agents` is privileged for DinD (contained as above); rootless BuildKit would remove it.
- 8 GB host: about 5.4 GB in use idle, a build adds 2–3 GB. Raise Docker swap to absorb peaks.
- Builds start from an empty DinD (Maven downloads every build); only the Trivy DB is cached.
- Single replicas of Jenkins, Traefik, ArgoCD and the monitoring components; no TLS on the lab hostnames.
- A clean Trivy result is one DB snapshot; rescan regularly and bump base images before end of life.
- `pod-security.kubernetes.io/enforce-version` is `latest`; pin it for stricter reproducibility.
- Rollback restores the previous Git state; data written by the app (none here) would not be reverted.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `curl http://…nip.io` → `000`/reset while `curl -k https://127.0.0.1` → `404` | Docker Desktop kept a stale port-80 forward after `kind delete cluster` | Quit and reopen Docker Desktop |
| After a Docker restart, `jenkins-0` stuck in `Init`, log ends with `cp: overwrite …?` | containers restarted in the same pod; plugin `emptyDir` already full | `kubectl delete pod jenkins-0 -n jenkins` |
| Jenkins `Init:Error`, `configmaps is forbidden` | chart RBAC disabled without the JCasC reload Role | Role `jenkins-casc-reload` (in `rbac.tf`) |
| `Failed Loading plugin` in Jenkins log | only top-level plugins pinned | pin the full tree (`jenkins-plugins.txt`) |
| ArgoCD app stuck `Progressing` | Ingress has no address in status | Traefik `ingressEndpoint.ip: 127.0.0.1` (set) |
| Promotion fails `403` pushing to GitOps | token lacks Contents write on `beacon-gitops` (the repo API's `permissions` shows your account, not the token) | test with `git push --dry-run`; regenerate the token |
| Scan fails `context deadline exceeded` | Trivy DB download slower than the timeout | cache PVC + 15-minute timeout (set) |
| No build after a push, poll log `No changes` | a Pipeline job polls the SCM recorded by its last build; after a branch change it needs one build | Build Now (or `bootstrap.sh` queues the first build) |
| Grafana `503` right after install | slow first start | wait; CPU limit 1 core and plugin preinstall disabled (set) |
| `503` from Traefik | backend not ready yet | `kubectl get pods -n <ns>` |
| Terraform prompts for a token | new terminal without `TF_VAR_*` | `source scripts/secrets-env.sh` |
| `Error: No configuration files` | Terraform run outside `terraform/` | `terraform -chdir=terraform …` from the repo root |
| `helm_release` stuck / Ctrl+C twice | release left `pending-install`, missing from state | `helm uninstall <name> -n <ns>`, plan, apply |
| `argocd` namespace stuck `Terminating` | Application finalizer with ArgoCD already gone | use `teardown.sh` (deletes the Application first) |
