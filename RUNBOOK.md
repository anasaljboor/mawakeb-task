# Beacon of Release — Runbook

Rebuild the lab from this repository alone. Status: Chapters 1–3 complete.

## Architecture

```
Mac (Docker Desktop, 8 GB)
 └─ Kind cluster "beacon"  ← scripts/cluster-up.sh (prerequisite, outside Terraform)
     ├─ beacon-control-plane   127.0.0.1:80/443 → NodePorts 30080/30443
     ├─ beacon-worker          label workload=apps
     └─ beacon-worker2         label workload=builds, taint dedicated=builds:NoSchedule

     Terraform owns everything inside the cluster:
     ├─ ns traefik         (PSA restricted)   Traefik ingress controller, NodePort
     ├─ ns jenkins         (PSA restricted)   Jenkins controller, PVC jenkins-home, secrets
     ├─ ns jenkins-agents  (PSA privileged)   ephemeral build pods, builds node only
     └─ ns beacon          (PSA restricted)   the application (Chapter 3)

Browser → jenkins.127.0.0.1.nip.io:80 → Kind :30080 → Traefik → Service jenkins:8080
```

**Boundary:** the Kind cluster is a local prerequisite created by a script. Terraform never creates
the cluster it connects to, so `terraform plan` works on a clean machine. No cloud infrastructure is used.

## Prerequisites

| Tool | Version used |
|---|---|
| macOS (Apple Silicon, arm64) | 27.0.1 |
| Docker Desktop (engine), 8 GB memory | 29.5.3 |
| kind | v0.33.0 (node image `kindest/node:v1.37.0`, pinned by digest) |
| kubectl | v1.36.2 |
| helm | v4.2.1 |
| terraform | v1.16.4 (`required_version = "~> 1.16"`) |
| trivy | 0.76.2 |
| python3 | 3.14 (plugin resolver only) |
| openssl | any (password generation) |

```bash
brew install kind kubectl helm terraform trivy
```

## Bootstrap

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```
Set `git_repo_url` and `dockerhub_username` in it (non-secret). Then:
```bash
./scripts/bootstrap.sh
```
It creates the cluster, loads secrets, runs `terraform init` and `plan`, **waits for you to review and
confirm**, applies, runs a second plan that must show no changes, and checks Jenkins answers HTTP 200.

Open http://jenkins.127.0.0.1.nip.io and log in as `admin`. Copy the password to the clipboard without
printing it:
```bash
kubectl get secret jenkins-admin -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d | pbcopy
```

Hostname resolution: `*.127.0.0.1.nip.io` is public wildcard DNS that resolves to `127.0.0.1`.
No `/etc/hosts` edits. Offline alternative: add `127.0.0.1 jenkins.127.0.0.1.nip.io` to `/etc/hosts`.

## Credentials and secrets

| Secret | Where it comes from | Where it lives |
|---|---|---|
| Docker Hub access token (Read & Write) | You, typed at a hidden prompt on first bootstrap | Secret `jenkins/dockerhub` → Jenkins credential `dockerhub` |
| Jenkins admin password | Generated (`openssl rand`) on first bootstrap | Secret `jenkins/jenkins-admin` |

- `source scripts/secrets-env.sh` exports them as `TF_VAR_*` for the current shell only. On later runs it
  reads the values back from the cluster, so you are only prompted once. Run it in every new terminal
  before any Terraform command.
- Terraform receives them as **ephemeral variables** and writes them through the provider's
  **write-only attribute** `data_wo`. They are never written to Git, `terraform.tfvars`, plan files,
  outputs, or state. Verified: `grep -c "$TF_VAR_dockerhub_token" terraform/terraform.tfstate` → `0`.
- Jenkins encrypts the credential at rest in `credentials.xml`.
- **Rotate:** export the new value (`export TF_VAR_jenkins_admin_password=...`), set
  `secrets_revision = <n+1>` in `terraform.tfvars`, plan, apply, then
  `kubectl rollout restart statefulset/jenkins -n jenkins`. Exercised once (revision 2).
- The cluster is the only copy of the Docker Hub token. Keep it in a password manager: after a full
  teardown you must type it again (or create a new one and revoke the old).

## Terraform state

- Local backend, `terraform/terraform.tfstate`, gitignored, `chmod 600`. It holds no secret values (see
  above), but it maps the infrastructure, so it is still protected.
- Saved plans (`tfplan`) are gitignored too: a plan can embed sensitive values.
- For a team: use a remote backend with encryption at rest, state locking, and restricted access
  (for example S3 + DynamoDB lock, or Terraform Cloud).

## Security design

**Namespaces and Pod Security Admission** — `restricted` everywhere except `jenkins-agents`.
`jenkins-agents` is `privileged` because image builds need Docker-in-Docker (Chapter 4). It is contained by:
the dedicated namespace, the tainted `builds` node (only agent pods tolerate it, so privileged containers never
share a node with Jenkins or the app), and agent pods carrying no Kubernetes API token.

**RBAC** — Roles only, no ClusterRoles of our own, nothing bound to cluster-admin.

| Service account | Allowed | Not allowed |
|---|---|---|
| `jenkins/jenkins` (controller) | manage pods, exec, logs in `jenkins-agents`; read ConfigMaps in `jenkins` (JCasC reload) | anything in `beacon`, secrets |
| `jenkins-agents/jenkins-agent` (build pods) | nothing; token not mounted | everything |
| `jenkins-agents/beacon-deployer` (deploy pods) | create/patch Deployments, Services, ConfigMaps, Ingresses in `beacon`; read ReplicaSets, pods, logs, events | delete, secrets, other namespaces |

Traefik's chart ClusterRole is the only cluster-wide grant: read-only (get/list/watch) on ConfigMaps, Nodes,
Namespaces, Pods, Services, EndpointSlices, Secrets (for TLS), IngressClasses, Ingresses and Traefik's CRDs,
plus `update` on `ingresses/status` only. An ingress controller must watch every namespace, so this is
the accepted exception. Reading Secrets cluster-wide is its most sensitive right; scoping Traefik with
`providers.kubernetesIngress.namespaces` would narrow it.

Evidence: [docs/evidence/rbac-can-i.txt](docs/evidence/rbac-can-i.txt). A root pod in `beacon` is rejected:
`violates PodSecurity "restricted:latest"`.

## Jenkins configuration as code

Nothing is configured by hand. Everything is in [terraform/values/jenkins.yaml.tftpl](terraform/values/jenkins.yaml.tftpl):

- Chart `jenkins` 5.13.3, controller image `jenkins/jenkins:2.580.2-jdk25`, 0 executors on the controller.
- Admin user from the `jenkins-admin` Secret: no setup wizard.
- Kubernetes cloud: agents in `jenkins-agents`, service account `jenkins-agent`, `nodeSelector workload=builds`
  plus the `dedicated=builds` toleration.
- Credential `dockerhub` from mounted Secret files.
- Pipeline job `beacon` created by Job DSL: `Jenkinsfile` on `main`, SCM polling every 2 minutes
  (GitHub webhooks cannot reach a laptop).
- Persistent home: PVC `jenkins-home` (8 Gi), owned by Terraform, not by the chart.

**Plugins** — [terraform/jenkins-plugins.txt](terraform/jenkins-plugins.txt) pins the full dependency tree
(79 plugins) with `installLatestPlugins: false`. Pinning only top-level plugins lets the installer pick minimum
dependency versions, which broke Pipeline: Declarative on the first install. To upgrade Jenkins, change
`jenkins_image_tag`, then regenerate and review the diff:
```bash
python3 scripts/resolve-jenkins-plugins.py <core-version> terraform/jenkins-plugins.txt
```

## Chapter 1 — image and scan

- Multi-stage [Dockerfile](Dockerfile): Maven build and tests run inside `docker build`; test reports are exported
  even when tests fail (`--target test-results`); the `verified` stage fails the build on test failure.
- Runtime: `alpine:3.24.2` + Alpine's `openjdk17-jre-headless`, UID 10001, read-only root filesystem, `/tmp` writable.
- Scan: `./scripts/scan.sh <image> [out-dir]` → Trivy OS + Java libraries, exit 1 on any finding or scanner
  error, JSON report, image ID, scanner and DB version.

```bash
docker build --target test-results --output type=local,dest=reports/tests .
docker build -t beacon:dev .
docker run --rm -d --name beacon -p 8080:8080 --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges -e YOUR_NAME=you beacon:dev
./scripts/scan.sh beacon:dev
```

## Chapter 3 — application on Kubernetes

Manifests in [k8s/](k8s/): `configmap.yaml` (`YOUR_NAME`), `deployment.yaml`, `service.yaml` (ClusterIP, internal),
`ingress.yaml` (class `traefik`, host `beacon.127.0.0.1.nip.io`).

- 2 replicas on the `apps` node, rolling update with `maxUnavailable: 0`, `progressDeadlineSeconds: 120`.
- Startup, readiness (`/actuator/health/readiness`) and liveness (`/actuator/health/liveness`) probes.
- Requests 100m/256Mi, limits 500m/512Mi.
- `runAsNonRoot` (UID 10001), `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, seccomp `RuntimeDefault`,
  `readOnlyRootFilesystem: true`, `emptyDir` on `/tmp`, no service account token. Passes PSA `restricted` in enforce mode.
- `preStop` sleep 5 s so Traefik drains a terminating pod before it stops.

The image is the placeholder `__IMAGE__`. `scripts/deploy.sh <image>` renders it, refuses `latest` or untagged images,
records `kubernetes.io/change-cause` (image and commit), applies, and waits for the rollout. If the rollout fails it
re-applies the previous image (declarative rollback, keeps `last-applied-configuration` consistent) and exits 1.
`scripts/smoke-test.sh <url>` checks the greeting and health.

Until Chapter 4 pushes to Docker Hub, deploy a locally built image:
```bash
TAG=$(git rev-parse --short=12 HEAD)
docker build -t beacon:$TAG . && ./scripts/scan.sh beacon:$TAG
kind load docker-image beacon:$TAG --name beacon
./scripts/deploy.sh docker.io/library/beacon:$TAG
./scripts/smoke-test.sh http://beacon.127.0.0.1.nip.io
```
Change the greeting: edit `YOUR_NAME` in `k8s/configmap.yaml`, deploy, then
`kubectl rollout restart deployment/beacon -n beacon` (env vars are read at start-up).

## Verification evidence

| Claim | Evidence |
|---|---|
| Image is clean | [docs/evidence/beacon-dev-trivy.json](docs/evidence/beacon-dev-trivy.json): 0 findings, image `sha256:c41de728…` |
| Scan gate fails closed | [docs/evidence/gate-test-alpine-3.18.0.json](docs/evidence/gate-test-alpine-3.18.0.json): 49 findings, exit 1; missing image → exit 1 |
| Least privilege | [docs/evidence/rbac-can-i.txt](docs/evidence/rbac-can-i.txt) |
| Idempotent Terraform | second `terraform plan -detailed-exitcode` → exit 0 |
| Jenkins from code | job `beacon`, credential `dockerhub`, cloud namespace `jenkins-agents`, 79 plugins, 0 load errors |
| App reachable through Ingress, healthy, self-healing, safe rollback | [docs/evidence/ch3-verification.txt](docs/evidence/ch3-verification.txt): one pod deleted under load 104/104 OK; failed rollout rolled back under load 189/189 OK |

## Teardown

```bash
./scripts/teardown.sh
```
`terraform destroy`: removes Traefik, Jenkins, its PVC, secrets, RBAC and namespaces. Keeps the cluster.

```bash
./scripts/teardown.sh --all
```
Also deletes the Kind cluster.

**What survives**

| Data | `teardown.sh` | `teardown.sh --all` |
|---|---|---|
| Git repository (all configuration) | kept | kept |
| Images and tags on Docker Hub | kept | kept |
| `terraform/terraform.tfvars` | kept | kept |
| Kind cluster | kept | **deleted** |
| Jenkins home: build history, logs, archived artifacts | **deleted** (StorageClass reclaim policy `Delete`) | **deleted** |
| Secrets (Docker Hub token, admin password) | **deleted** | **deleted** |

Jenkins configuration is rebuilt identically from code; only build history is lost. Uninstalling just the Helm
chart (`helm uninstall jenkins -n jenkins`) keeps `jenkins-home`, because Terraform owns the PVC, not the chart.

## Known limitations

- Images are built for arm64 (Apple Silicon); the Kind nodes are arm64 too.
- Local Terraform state, single operator. See "Terraform state" for the team setup.
- SCM polling (2 min) instead of webhooks: the lab is not reachable from GitHub.
- `jenkins-agents` is privileged for Docker-in-Docker; contained as described above. Rootless BuildKit would remove it.
- A clean Trivy scan reflects one vulnerability-DB snapshot; it must be rerun, and base images bumped before they reach end of life.
- `pod-security.kubernetes.io/enforce-version` is `latest`; pin it to the cluster version for stricter reproducibility.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `curl http://jenkins.127.0.0.1.nip.io` → `000` / "connection reset", while `curl -k https://127.0.0.1` → `404` | Docker Desktop keeps a stale port-80 forward after `kind delete cluster` | Quit and reopen Docker Desktop (`osascript -e 'quit app "Docker Desktop"'`, then `open -a "Docker Desktop"`) |
| After a Docker Desktop restart, `jenkins-0` stuck in `Init`, init log ends with `cp: overwrite '/var/jenkins_plugins/...'?` | Containers restart inside the same pod, so the plugin `emptyDir` is already populated | `kubectl delete pod jenkins-0 -n jenkins` (data is on the PVC) |
| `503` from Traefik | Jenkins not ready yet, or Traefik has not seen the new pod | Wait; `kubectl get pods -n jenkins` |
| Terraform prompts for `dockerhub_token` | New terminal without `TF_VAR_*` | `source scripts/secrets-env.sh` |
| `Error: No configuration files` | Ran Terraform outside `terraform/` | Run from the repo root with `terraform -chdir=terraform ...` |
| `helm_release` stuck / Ctrl+C pressed twice | Terraform killed before recording the release (`pending-install`, missing from state) | `helm uninstall <name> -n <ns>`, then plan and apply again |
