output "url" { value = "http://${var.hostname}" }
output "application" { value = "${var.namespaces.argocd}/${var.app_name}" }
output "sync_service_account" { value = "${var.namespaces.app}/${kubernetes_service_account_v1.sync.metadata[0].name}" }
