# The Beacon of Release

A Java 17 Spring Boot service (`GET /` → `hello <name>`, `/actuator/health`) and the delivery platform around it:
a Terraform-built lab on Kind with Jenkins on Kubernetes agents, Trivy gates, Docker Hub, ArgoCD GitOps, and
Prometheus/Grafana/Loki observability. The assignment is in [TASK.md](TASK.md).

**Start here: [RUNBOOK.md](RUNBOOK.md)** — architecture, repository map, prerequisites, bootstrap from zero,
credentials, security design, pipeline, GitOps, observability, evidence, teardown, known limitations, troubleshooting.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
./scripts/bootstrap.sh
```
