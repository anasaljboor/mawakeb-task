# Terraform modules and environments — evidence

Rebuild of the lab with the module/environment layout (branch `terraform-modules-azure`), 2026-11-24.
Every reading below was taken live from the running lab during this session; times are UTC.

## Rebuild from zero (local environment)

| Step | Result |
|---|---|
| Old cluster removed | `kind delete cluster --name beacon`; Docker Desktop restarted to clear port forwards |
| `environments/local/cluster` plan | 1 to add: `module.kind_cluster.kind_cluster.this` (pinned node image, ports 80/443 on 127.0.0.1, `builds` taint) |
| Cluster apply | created in 33 s; context `kind-beacon` merged; `beacon-worker2` taint `dedicated=builds:NoSchedule` |
| `environments/local/platform` plan | 34 to add, 0 to change, 0 to destroy (same count as the former single-root stack) |
| `bootstrap.sh` (reviewed plans, both stacks) | cluster: no changes; platform: 34 added |
| **Second plan, both stacks** | `terraform plan -detailed-exitcode` → **exit 0** for `local/cluster` and `local/platform` |
| Secrets in platform state | registry token **0** occurrences, GitHub token **0** occurrences |
| State files | `chmod 600`; resources: [state-local-cluster.txt](terraform-modules/state-local-cluster.txt) (1), [state-local-platform.txt](terraform-modules/state-local-platform.txt) (35 = 34 resources + the cluster remote-state data source) |
| Jenkins from code | job `beacon`, 79 plugins, 0 plugin load errors, credentials `registry` and `gitops` |
| ArgoCD | `Synced Healthy` at GitOps revision `199680f`, running `…@sha256:5d6d9658…` with no build needed |
| URLs through Traefik | Jenkins 200, ArgoCD 200, Grafana 200, app 200 `hello anas` |
| Static checks | `terraform fmt -check -recursive` clean; `validate` succeeds for all five roots (`local/cluster`, `local/platform`, `azure/state`, `azure/cluster`, `azure/platform`); lock files for darwin/linux × arm64/amd64 |

Cold start note: on the first install both Beacon pods restarted twice (16 pods started at once on the apps node while
build #1 ran; the JVM did not open port 8080 inside the 90 s startup window). They recovered unaided. The startup
probe budget in `k8s/deployment.yaml` was raised to 180 s; that change is in the branch and reaches the cluster with
the next successful promotion.

## Pipeline on the new layout

| Build | Commit | Tests | Scan | Publish | Promote | Meaning |
|---|---|---|---|---|---|---|
| #1 | `87a9d07` (`main`, old Jenkinsfile) | 5/5 | 0 findings | stopped: credential `dockerhub` not found | skipped | old Jenkinsfile vs new credential name; nothing pushed |
| #2 | `e9942dd` (branch) | 5/5 | 0 findings | ✅ `beacon:e9942dd2ad07` | GitOps diff = `deployment.yaml` (probe change from `k8s/`) + `kustomization.yaml` (digest); push rejected `401` | proved the `k8s/` → GitOps copy; exposed a misleading failure message (fixed in `77354b6`) |
| #3 | `77354b6` (branch) | 5/5 | 0 findings | ✅ `beacon:77354b689c77` | push rejected; reported correctly: `PUSH FAILED … nothing was promoted and production is unchanged` | [build3-release.json](terraform-modules/build3-release.json) `result: failed-gitops-push`, empty `gitopsCommit` |

Both rejections came from the GitHub token stored at bootstrap: valid format (`github_pat_`, 93 characters) but
GitHub answered `401` (revoked or expired). Production was never affected: `beacon-gitops` stayed at `199680f` and
ArgoCD stayed `Synced Healthy`. This is the fail-closed behaviour the task asks for, observed live.

## Open at hand-in

- The GitHub token must be rotated before the next promotion (RUNBOOK → Credentials → Rotate). End-to-end promotion
  on the new layout is therefore shown up to the push; the full promote → sync → smoke path is evidenced by builds
  #14 and #15 on the previous layout ([gitops/](gitops/)), whose promote logic is unchanged apart from copying `k8s/`.
- The Azure environment is code-complete and validated, not deployed (no subscription on this machine).
