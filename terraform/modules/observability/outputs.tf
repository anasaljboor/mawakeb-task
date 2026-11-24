output "grafana_url" { value = "http://${var.grafana_hostname}/d/beacon" }
output "grafana_admin_secret" { value = "${var.namespaces.monitoring}/${kubernetes_secret_v1.grafana_admin.metadata[0].name}" }
