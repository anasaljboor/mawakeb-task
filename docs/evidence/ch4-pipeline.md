# Chapter 4 — pipeline evidence

Jenkins job `beacon`, branch `ch4-pipeline`, builds #2–#11 (2026-11-23). Every row was read back from the
Jenkins API, Docker Hub and the cluster, not from expectations.

| Build | Commit | Change | Result | Tests | Stopped at | Published | Deploy |
|---|---|---|---|---|---|---|---|
| #2 | `35a29930a4c5` | pipeline added | SUCCESS | 4/4 | — | `@sha256:3af215a7…` | rolled out, smoke OK |
| #3 | `86dcc86bd057` | deploy.sh full-revision rollback | SUCCESS | 4/4 | — | `@sha256:e330f5cd…` | succeeded |
| **#4** | `6e6c14426b59` | **demo A: failing test** | **FAILURE** | **3 passed, 1 failed** | 2. Build and test | **no** (tag absent on Docker Hub) | not reached |
| #5 | `9f895b62db9f` | revert A | SUCCESS | 4/4 | — | `@sha256:fd00d7e1…` | succeeded |
| **#6** | `06b35ac82c1c` | **demo B: log4j-core 2.14.1** | **FAILURE** | 4/4 | **3. Security scan** (8 findings, 2 CRITICAL incl. CVE-2021-44228) | **no** (tag absent on Docker Hub) | not reached |
| #7 | `9ff6bbd9358c` | revert B | SUCCESS | 4/4 | — | `@sha256:6d7f70f8…` | succeeded |
| #8 | `4acdee8211db` | accidental re-apply of B | FAILURE | 4/4 | 3. Security scan (same findings) | no | not reached |
| #9 | `7961fa199bb0` | revert | SUCCESS | 4/4 | — | `@sha256:dd5eb46f…` | succeeded |
| **#10** | `389196c73a3f` | **demo C: readiness probe → `/does-not-exist`** | **FAILURE** | 4/4 | **5. Deploy** (rollout not complete in 180 s) | yes `@sha256:e5ee371b…` | **previous revision `@sha256:dd5eb46f…` restored, smoke OK** |
| #11 | `1d5acd82d397` | revert C | SUCCESS | 4/4 | — | `@sha256:d925de66…` | succeeded |

## Gates

- **Failing test blocks publication and deployment** — #4: surefire reports exported and recorded by `junit`
  (`expected "hello WRONG" but was "hello explorer"`); the `verified` Docker stage exits 1; stages 3–5 skipped;
  `docker manifest inspect anasaljboor/beacon:6e6c14426b59` → not found.
- **Vulnerability blocks publication and deployment** — #6: tests pass, Trivy reports
  `Total: 8 (MEDIUM: 5, HIGH: 1, CRITICAL: 2)` including `log4j-core 2.14.1 CVE-2021-44228` found inside
  `app.jar`; report archived ([ch4/build6-trivy-log4shell.json](ch4/build6-trivy-log4shell.json));
  `anasaljboor/beacon:06b35ac82c1c` → not found. #8 reproduced it independently.
- **Failed rollout exercises recovery** — #10: image published (nothing wrong with it), Deployment applied,
  new pod never Ready, `DEPLOY FAILED … rollout did not complete within 180s`, last-applied Deployment re-applied
  (image **and** probe restored), smoke test passed, build failed with the reason;
  [ch4/build10-release-rolled-back.json](ch4/build10-release-rolled-back.json) `result: failed-previous-revision-restored`.

## Exact image shipped (build #11)

| Source | Digest |
|---|---|
| Trivy report `Metadata.ImageID` ([ch4/build11-trivy-clean.json](ch4/build11-trivy-clean.json), 0 findings) | `sha256:d925de664878f209e4ac95a8298135a04543b286d7cb903b7c74e3287cff73f5` |
| `release.json` `imageRef` ([ch4/build11-release-success.json](ch4/build11-release-success.json)) | `docker.io/anasaljboor/beacon@sha256:d925de664878…` |
| Running Deployment | `docker.io/anasaljboor/beacon@sha256:d925de664878…` |

Scanner: Trivy 0.76.2, vulnerability DB updated `2026-11-23T01:05:17Z`
([ch4/build11-trivy-version.json](ch4/build11-trivy-version.json)).

## Rollout history (change-cause written by deploy.sh)

```
13  jenkins build=10 commit=389196c73a3f image=…@sha256:e5ee371b…
14  rollback after rollout did not complete within 180s of …@sha256:e5ee371b…
15  jenkins build=11 commit=1d5acd82d397 image=…@sha256:d925de66…
```
