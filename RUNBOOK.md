# Beacon of Release — Runbook

A Java 17 Spring Boot service delivered by a Terraform-built lab: Jenkins on Kubernetes builds, tests and scans it,
publishes it to Docker Hub by commit, and promotes the exact digest through a GitOps repository that ArgoCD
reconciles. Prometheus, Grafana and Loki watch it. Everything below can be rebuilt from this repository, the
`beacon-gitops` repository, and two tokens.

Status: Chapters 1–4, the Final Trial, the optional GitOps expedition, and an observability stack — all done.
Infrastructure is organized as Terraform modules and environments (local Kind, running; Azure AKS, code-complete).

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

## TASK.md compliance

| Requirement | Where | Evidence |
|---|---|---|
| Ch1 multi-stage `Dockerfile`, tests inside `docker build`, no host Java/Maven | [Dockerfile](Dockerfile) | build #4: failing test stops the build |
| Ch1 greeting, env var, health from the container; non-root, read-only, writable `/tmp` | Dockerfile, [Image and scan](#image-and-scan-chapter-1) | `docker run --read-only --tmpfs /tmp …` |
| Ch1 Trivy OS + Java, report + digest, no ignore lists | [scripts/scan.sh](scripts/scan.sh) | [beacon-dev-trivy.json](docs/evidence/beacon-dev-trivy.json), [ch4/build11-trivy-clean.json](docs/evidence/ch4/build11-trivy-clean.json) |
| Ch2 cluster choice and boundary documented; cloud infra only via Terraform | Kind created by `terraform/environments/local/cluster`; Azure state, network, AKS, ACR, Key Vault all Terraform | [Terraform layout](#terraform-layout) |
| Ch2 `terraform/` directory: Jenkins install, storage, service access, namespace, service account, scoped RBAC | [terraform/modules/jenkins](terraform/modules/jenkins), [terraform/modules/platform-namespaces](terraform/modules/platform-namespaces) | [rbac-can-i.txt](docs/evidence/rbac-can-i.txt) |
| Ch2 Kubernetes plugin with temporary agents, JCasC, reproducible plugin list, job from code, no setup clicks | [values.yaml.tftpl](terraform/modules/jenkins/values.yaml.tftpl), [plugins.txt](terraform/modules/jenkins/plugins.txt) | 79 plugins, 0 load errors; no wizard |
| Ch2 credentials out of Git and outputs; secret injection and state protection documented | write-only `data_wo` + ephemeral variables; [Credentials](#credentials-and-secrets), [Terraform state](#terraform-state) | `grep` of the token in state → `0` |
| Ch2 pinned providers and charts, committed lock files, non-secret outputs, example inputs | every root under `terraform/environments/` | `.terraform.lock.hcl` and `terraform.tfvars.example` per root |
| Ch2 init → reviewed plan → apply; second plan clean; teardown and surviving data | `scripts/bootstrap.sh` (stops for review), [Teardown](#teardown) | [terraform-modules.md](docs/evidence/terraform-modules.md): rebuild from zero, second plan exit 0 for both stacks, tokens in state 0 |
| Ch3 `k8s/deployment.yaml`, `service.yaml`, `ingress.yaml` | [k8s/](k8s/) | — |
| Ch3 ingress controller + hostname resolution | [terraform/modules/ingress-traefik](terraform/modules/ingress-traefik); nip.io documented | — |
| Ch3 probes, requests/limits, non-root, no escalation, dropped caps, read-only root + writable tmp, `YOUR_NAME` from config, internal Service, digests not `latest` | [k8s/](k8s/) + digest in `beacon-gitops` | PSA `restricted` enforce dry run; [ch3-verification.txt](docs/evidence/ch3-verification.txt) |
| Ch3 reachable through Ingress, healthy, recovers after pod deletion | — | [ch3-verification.txt](docs/evidence/ch3-verification.txt): 104/104 OK |
| Ch4 root `Jenkinsfile` on Kubernetes agents, gates 1–6 in order | [Jenkinsfile](Jenkinsfile), [Pipeline](#pipeline-chapter-4--gitops) | [ch4-pipeline.md](docs/evidence/ch4-pipeline.md) |
| Ch4 test results kept on failure; Trivy fails closed; report, DB time, scanner version archived | Jenkinsfile stages 2–3 | builds #4, #6, #13; a rejected GitOps push also fails closed (new layout #3) |
| Ch4 Jenkins credentials, push to Docker Hub with commit tag, capture digest | stage 4 (`registry` credential = Docker Hub locally) | `release.json`; new layout builds #2–#3 publish with `registry` |
| Ch4 deploy that digest, wait with timeout, smoke test through Ingress, restore known-good on failure, record result | stage 5 via GitOps (Optional: ArgoCD owns deployment) | build #10 (rollback), #14–#15 (GitOps), `release.json` |
| Ch4 how agents build images; DinD risks and isolation; no cluster-admin for deploy; no racing | [Security design](#security-design), `lock` + `disableConcurrentBuilds` | — |
| Final Trial: app, Dockerfile, Jenkinsfile, Terraform, Jenkins config, manifests, runbook | this repository + `beacon-gitops` | this file |
| Optional: ArgoCD via Terraform, manifests in a GitOps repo, Jenkins commits digests, no direct deploy | [terraform/modules/argocd](terraform/modules/argocd), `scripts/gitops-promote.sh` | [docs/evidence/gitops/](docs/evidence/gitops/) |
| Optional: demonstrate sync and health | builds #14, #15 | [gitops-repo-log.txt](docs/evidence/gitops/gitops-repo-log.txt), [argocd-application.json](docs/evidence/gitops/argocd-application.json) |
| Optional: demonstrate drift correction and rollback through `git revert` | [GitOps with ArgoCD](#gitops-with-argocd) gives the commands | **not yet demonstrated** |
| Note: monitoring | [terraform/modules/observability](terraform/modules/observability) | [observability/verification.txt](docs/evidence/observability/verification.txt) |

## Architecture

```
Mac (Docker Desktop, 8 GB) ── 127.0.0.1:80/443 ──► Kind cluster "beacon"   (Terraform: environments/local/cluster)
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
| `terraform/modules/` | reusable modules: cluster (`kind-cluster`, `azure-network`, `aks-cluster`, `container-registry`, `key-vault`, `cost-budget`) and platform (`platform-namespaces`, `ingress-traefik`, `jenkins`, `argocd`, `observability`), each with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and its chart values |
| `terraform/environments/` | `local/{cluster,platform}` (Kind, runs today) and `azure/{state,cluster,platform}` (AKS, code-complete, gated); each root pins versions and has a lock file and `terraform.tfvars.example` |
| `k8s/` | **source of truth** for the manifests: `configmap.yaml`, `deployment.yaml`, `service.yaml`, `ingress.yaml` (image name `beacon`, resolved to a digest by the GitOps repo) |
| `scripts/` | `bootstrap.sh`, `teardown.sh`, `secrets-env.sh`, `scan.sh`, `smoke-test.sh`, `gitops-seed.sh`, `gitops-promote.sh`, `resolve-jenkins-plugins.py` |
| `docs/evidence/` | scan reports, RBAC checks, Chapter 3 and 4 verification, GitOps and observability evidence |
| **`beacon-gitops`** repo | deployed state: `apps/beacon/` = copies of `k8s/` from the released commit + `kustomization.yaml` pinning the image digest; written only by Jenkins |

## Terraform layout

Same conventions as markaba-infra: components are modules, environments compose them, providers are passed explicitly,
versions are pinned only in environment roots, and costly or risky inputs sit behind gates.

```
terraform/
  modules/
    kind-cluster         Kind cluster: pinned node image, apps + tainted builds workers, 80/443 on 127.0.0.1
    azure-network        VNet, subnets (no default outbound), NSGs allowing only 80/443 from ingress_source_ranges
    aks-cluster          AKS: Entra RBAC, local accounts off, OIDC + workload identity, Azure CNI overlay + Cilium,
                         system pool (critical add-ons only) + user pools apps and builds (taint, scales to zero),
                         Azure Policy, auto-upgrade channels, authorized API ranges, optional Container Insights
    container-registry   ACR (no admin user, no anonymous pull), AcrPull for the kubelet, repo-scoped CI push token
    key-vault            Key Vault (RBAC, purge protection, network deny by default), officer/reader role assignments
    cost-budget          Monthly resource-group budget, alerts at 80 % actual and 100 % forecast
    state-storage        Terraform state account: Entra-only (no keys), TLS 1.2, ZRS, versioning, soft delete, deny by default
    platform-namespaces  Namespaces with Pod Security labels
    ingress-traefik      Traefik: NodePort + fixed address (Kind) or Azure Load Balancer on a static IP (AKS)
    jenkins              Service accounts, scoped Roles, PVCs, write-only secrets, JCasC, 79 pinned plugins
    argocd               ArgoCD, AppProject + Application, sync identity in the app namespace
    observability        Prometheus, Grafana, Loki, Alloy, alert rules, Beacon dashboard
  environments/
    local/cluster        kind-cluster
    local/platform       platform modules on Kind (reads context from the cluster state)
    azure/cluster        resource group, network, aks, registry, key vault, budget, static ingress IP
    azure/state          state-storage (applied first, with local state, so no Azure resource is created by hand)
    azure/platform       the same platform modules on AKS (Entra login, secrets from Key Vault)
```

**Two stacks per environment.** A root cannot reliably configure its Kubernetes and Helm providers from a cluster it
creates in the same run, so the cluster and the platform are separate states. `local/platform` reads the context name
from `local/cluster` through `terraform_remote_state`; `azure/platform` takes the cluster outputs as inputs.

**Same platform, two clouds.** Only inputs differ: ingress type, storage class (`standard` vs `managed-csi`), registry
(Docker Hub vs ACR), hostnames (`127.0.0.1.nip.io` vs `<static IP>.nip.io` or your domain), and where secrets come from.

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
   cp terraform/environments/local/platform/terraform.tfvars.example terraform/environments/local/platform/terraform.tfvars
   ```
   Set `git_repo_url`, `registry_username`, `gitops_repo_url` (and `git_branch` if not `main`).

2. One command:
   ```bash
   ./scripts/bootstrap.sh
   ```
   It checks the prerequisites, then runs two stacks in order. **Cluster:** `terraform init` and `plan` of
   `environments/local/cluster`, **waits for your review**, creates the Kind cluster (about 40 seconds), checks a second
   plan is clean. **Platform:** loads secrets (prompting only for the two tokens on a fresh cluster), plans
   `environments/local/platform`, **waits for your review**, applies (about 10 minutes), checks a second plan is clean.
   Then it checks Jenkins, ArgoCD and Grafana answer HTTP 200, reports the ArgoCD application state, and queues the
   first Jenkins build (SCM polling only starts after one build).

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
| Registry token (Docker Hub locally, ACR on Azure) | you, hidden prompt (Key Vault on Azure) | `jenkins/registry` | Jenkins credential `registry` (push) |
| GitHub token | you, hidden prompt | `jenkins/gitops` | Jenkins credential `gitops` (commit digests) |
| Jenkins admin password | generated (`openssl rand`) | `jenkins/jenkins-admin` | Jenkins login |
| Grafana admin password | generated | `monitoring/grafana-admin` | Grafana login |
| ArgoCD admin password | generated by ArgoCD | `argocd/argocd-initial-admin-secret` | ArgoCD login |

- `source scripts/secrets-env.sh` exports them as `TF_VAR_*` for the current shell. It reads existing values back from
  the cluster, so you are prompted only on a fresh cluster. Run it in every new terminal before Terraform.
- Terraform takes them as **ephemeral variables** and writes them through **write-only attributes** (`data_wo`): never
  in Git, `terraform.tfvars`, plan files, outputs or state. Verified: `grep -c "$TF_VAR_registry_token" terraform/environments/local/platform/terraform.tfstate` → `0`.
- Jenkins encrypts credentials at rest; the pipeline masks them in logs; `docker login` uses `--password-stdin`; the
  GitHub token reaches git through a credential helper, never in a URL.
- **Rotate:** export the new value, set `secrets_revision = <n+1>` in `terraform.tfvars`, plan, apply, then restart the
  consumer (`kubectl rollout restart statefulset/jenkins -n jenkins`). Exercised once (revision 2).
- The cluster holds the only copy of the tokens: keep them in a password manager. Delete unused tokens.

## Terraform state

- Local backend, one state per stack (`environments/local/cluster` and `environments/local/platform`), gitignored,
  `chmod 600` by `bootstrap.sh`. Saved plans (`tfplan`) are gitignored too.
- **The platform state holds no secret values** (write-only attributes, above).
- **The cluster state does hold the Kind cluster's admin client certificate and key**: the Kind provider stores them as
  resource attributes (it does not even mark them sensitive; our module outputs mark them sensitive and no root
  outputs them). Treat `environments/local/cluster/terraform.tfstate` like a kubeconfig. On AKS this does not arise:
  local accounts are disabled and access is Entra ID, so the cluster state holds no reusable credential.
- For a team, and on Azure: the `azurerm` backend (Storage Account blob with Entra ID auth, native lease locking,
  versioning and soft delete). Credential-free templates: `environments/azure/*/backend.azurerm.tf.example`; rename to
  `backend.tf` only after the storage account exists and access is restricted.
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

[terraform/modules/jenkins/values.yaml.tftpl](terraform/modules/jenkins/values.yaml.tftpl): chart 5.13.3, `jenkins/jenkins:2.580.2-jdk25`,
0 controller executors, admin from a Secret (no wizard), Kubernetes cloud (`jenkins-agents`, `jenkins-agent`, builds node),
credentials `registry` and `gitops` from mounted Secrets, global variables (`REGISTRY_SERVER`, `IMAGE_REPO`, `GITOPS_*`, `ARGOCD_*`,
`APP_HOSTNAME`, `INGRESS_URL`), and job `beacon` created by Job DSL (Jenkinsfile from `git_branch`, polling every 2 min).

[terraform/modules/jenkins/plugins.txt](terraform/modules/jenkins/plugins.txt) pins the full dependency tree (79 plugins). Upgrade:
change `jenkins_image_tag`, then regenerate and review the diff:
```bash
python3 scripts/resolve-jenkins-plugins.py <core-version> terraform/modules/jenkins/plugins.txt
```

## Kubernetes manifests (Chapter 3)

They live in **[k8s/](k8s/)** in this repository — the source of truth, reviewed in pull requests. On each release
Jenkins copies them into `beacon-gitops/apps/beacon/` together with the new digest, so the GitOps repository is the
deployed state and a `git revert` there rolls back manifests and image together. 2 replicas on the apps node; rolling update with `maxUnavailable: 0`; startup, readiness
(`/actuator/health/readiness`) and liveness probes; requests 100m/256Mi, limits 500m/512Mi; non-root UID 10001, no
privilege escalation, all capabilities dropped, seccomp, read-only root filesystem with an `emptyDir` on `/tmp`, no
service account token; `preStop` sleep so Traefik drains; `YOUR_NAME` from a ConfigMap; ClusterIP Service; Ingress
class `traefik`; image pinned by digest in `kustomization.yaml`.

Change the greeting: edit `YOUR_NAME` in `k8s/configmap.yaml`, merge; the next release carries it to `beacon-gitops`.
Then `kubectl rollout restart deployment/beacon -n beacon` (env is read at start-up).

## Pipeline (Chapter 4 + GitOps)

| # | Stage | Pod / container | Fails closed on |
|---|---|---|---|
| 1 | Checkout, print commit, stash scripts | build / `jnlp` | — |
| 2 | `docker build` with tests; reports exported first and recorded by `junit` even on failure | build / `docker` → DinD | any test failure |
| 3 | `scan.sh`; archives `trivy.json`, `trivy-version.json` (version, DB `UpdatedAt`), `image-id.txt`; DB cached on PVC `trivy-cache` | build / `trivy` | any finding or scanner error |
| 4 | push `IMAGE_REPO:<12-char sha>`, read `@sha256` digest | build / `docker` | login or push error |
| 5 | `gitops-promote.sh`: copy `k8s/*.yaml` from the built commit and set the digest in `beacon-gitops`, commit, wait (≤ 5 min) for ArgoCD `Synced`+`Healthy` at that commit, smoke test through Traefik; on failure `git revert` its own commit, wait for recovery, fail the build. Always archive `release.json` | promote / `kubectl` | sync timeout, `Degraded`, smoke failure |

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
- **Beacon dashboard** ([terraform/modules/observability/dashboards/beacon.json](terraform/modules/observability/dashboards/beacon.json), 13 panels): replicas, request rate,
  5xx ratio, restarts, requests by URI/status, latency p50/p95/p99, JVM heap, CPU, Traefik requests by code, running
  image digest, Traefik access log for the Beacon route, app logs, Jenkins/ArgoCD logs.
- **Alerts** (visible in Prometheus and Grafana): `BeaconDown`, `BeaconHighErrorRate` (> 5 % 5xx), `BeaconPodRestarting`.
  `BeaconDown` fired while the running image had no metrics endpoint and resolved when build #15 shipped it.

Evidence: [docs/evidence/observability/verification.txt](docs/evidence/observability/verification.txt).

## Azure environment

Code-complete and validated (`terraform validate` against `azurerm` 5.14.0, Helm 3.3.0, Kubernetes 3.5.0), **not
deployed**: every resource sits behind `deploy_azure = false` / `deploy_platform = false`, and a `terraform_data`
input guard refuses unsafe inputs (placeholder subscription, no Entra admin group, `0.0.0.0/0` admin range, no budget
recipients).

| Concern | Kind (local) | AKS (azure) |
|---|---|---|
| Cluster | `kind_cluster`, 1 control plane + 2 workers | AKS Standard tier, system pool + `apps` (1–3) + `builds` (0–2, tainted) |
| Cluster access | kubeconfig client certificate | Entra ID + Azure RBAC, `local_account_disabled`, `kubelogin`, authorized IP ranges |
| Network | Docker network | VNet `10.50.0.0/16`, Azure CNI overlay, Cilium data plane and network policy, NSG 80/443 only |
| Ingress | NodePort, `127.0.0.1` | Azure Standard Load Balancer on a static public IP, `externalTrafficPolicy: Local` |
| Registry | Docker Hub | ACR; kubelet pulls via AcrPull (no pull secret); CI pushes with a repository-scoped token |
| Secrets | `TF_VAR_*` from `secrets-env.sh` | Key Vault, read by ephemeral `azurerm_key_vault_secret`: never in state |
| Policy | Pod Security Admission | Pod Security Admission + Azure Policy add-on |
| Storage | `standard` (local-path) | `managed-csi` (Azure Disk) |
| Cost control | — | `cost-budget` alerts; builds pool scales to zero; Container Insights opt-in |
| State | local | `azurerm` backend template |

Deploying for real:

1. `environments/azure/state`: set subscription, tenant, a globally unique `storage_account_name`, your admin CIDR and
   the principals that run Terraform; `deploy_azure = true`; plan, review, apply. Put its `backend_config` output into
   both `backend.azurerm.tf.example` files and rename them to `backend.tf`.
2. `environments/azure/cluster`: copy `terraform.tfvars.example`, set subscription, tenant, globally unique `acr_name`
   and `key_vault_name`, Entra admin group, your admin CIDR, budget e-mail; set `deploy_azure = true`; `az login`;
   plan, review, apply.
3. Put the secrets in Key Vault (never through Terraform): generate the ACR token password with
   `az acr token credential generate --registry <acr> --name ci-push --password1`, then
   `az keyvault secret set` for `registry-token`, `github-token`, `jenkins-admin-password`, `grafana-admin-password`.
4. `environments/azure/platform`: copy the cluster outputs (`terraform output`) into `terraform.tfvars`, set
   `deploy_platform = true`, plan, review, apply. Hostnames default to `<ingress IP>.nip.io`; set `base_domain` for your own DNS.
5. Seed `beacon-gitops` with the ACR digest (`scripts/gitops-seed.sh`) and queue the first Jenkins build.

Azure-specific gaps, accepted for this lab: no private cluster or private endpoints (API and Key Vault are IP
restricted instead), no TLS on the ingress, and CI pushes with an ACR token rather than workload identity (OIDC and
workload identity are enabled on the cluster for that next step).

## Operations

| Task | How |
|---|---|
| Release | push to `git_branch`; watch the job |
| Roll back | `git revert` the deploy commit in `beacon-gitops` |
| Inspect a release | Jenkins build → `release.json` (commit, digest, GitOps commit, previous image, Trivy version and DB time, result) |
| Rotate a secret | export new value, bump `secrets_revision`, plan, apply, restart consumer |
| Upgrade Jenkins | bump `jenkins_image_tag`, regenerate `modules/jenkins/plugins.txt`, plan, apply |
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
| Module/environment layout rebuilt from zero | [terraform-modules.md](docs/evidence/terraform-modules.md) |
| GitOps promotion | [gitops-repo-log.txt](docs/evidence/gitops/gitops-repo-log.txt), [build14-release.json](docs/evidence/gitops/build14-release.json), [build15-release.json](docs/evidence/gitops/build15-release.json), [argocd-application.json](docs/evidence/gitops/argocd-application.json) |
| Observability | [verification.txt](docs/evidence/observability/verification.txt), [beacon-dashboard-panels.json](docs/evidence/observability/beacon-dashboard-panels.json) |

## Teardown

```bash
./scripts/teardown.sh
```
Deletes the ArgoCD Application first (so its finalizer runs while ArgoCD is alive), then destroys the platform stack. Keeps the cluster.

```bash
./scripts/teardown.sh --all
```
Also destroys the cluster stack (`terraform destroy` of `environments/local/cluster` removes the Kind cluster and its kubeconfig context).
After a cluster rebuild, restart Docker Desktop before the next apply if port 80 stops answering (see Troubleshooting).

| Data | `teardown.sh` | `--all` |
|---|---|---|
| This repository, `beacon-gitops` (desired state + deploy history), Docker Hub images | kept | kept |
| `terraform.tfvars` files; tokens in your password manager | kept | kept |
| Kind cluster | kept | deleted |
| Jenkins home (build history, artifacts), Prometheus TSDB, Loki chunks, Trivy cache | deleted (reclaim policy `Delete`) | deleted |
| In-cluster secrets | deleted | deleted |

Configuration comes back identically from code; only history and metrics are lost. `helm uninstall jenkins -n jenkins`
alone keeps `jenkins-home`, because Terraform owns that PVC.

## Known limitations

- **At hand-in the stored GitHub token is revoked** (GitHub answers 401), so promotions stop at the push and report
  `failed-gitops-push`; production is unaffected. Rotate it (Credentials → Rotate: new token, `secrets_revision = 2`,
  apply, restart Jenkins), then Build Now.
- The `k8s/` startup-probe change (180 s budget) is committed but not yet released to the cluster for the same reason.

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
| `Failed Loading plugin` in Jenkins log | only top-level plugins pinned | pin the full tree (`modules/jenkins/plugins.txt`) |
| ArgoCD app stuck `Progressing` | Ingress has no address in status | Traefik `ingressEndpoint.ip: 127.0.0.1` (set) |
| Promotion fails `403` pushing to GitOps | token lacks Contents write on `beacon-gitops` (the repo API's `permissions` shows your account, not the token) | test with `git push --dry-run`; regenerate the token |
| Scan fails `context deadline exceeded` | Trivy DB download slower than the timeout | cache PVC + 15-minute timeout (set) |
| No build after a push, poll log `No changes` | a Pipeline job polls the SCM recorded by its last build; after a branch change it needs one build | Build Now (or `bootstrap.sh` queues the first build) |
| Grafana `503` right after install | slow first start | wait; CPU limit 1 core and plugin preinstall disabled (set) |
| `503` from Traefik | backend not ready yet | `kubectl get pods -n <ns>` |
| Terraform prompts for a token | new terminal without `TF_VAR_*` | `source scripts/secrets-env.sh` |
| `Error: No configuration files` | Terraform run outside a stack folder | `terraform -chdir=terraform/environments/local/<cluster or platform> …` |
| `helm_release` stuck / Ctrl+C twice | release left `pending-install`, missing from state | `helm uninstall <name> -n <ns>`, plan, apply |
| `argocd` namespace stuck `Terminating` | Application finalizer with ArgoCD already gone | use `teardown.sh` (deletes the Application first) |
