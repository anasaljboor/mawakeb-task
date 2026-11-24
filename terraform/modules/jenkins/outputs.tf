output "url" { value = "http://${var.hostname}" }
output "admin_secret" { value = "${var.namespaces.jenkins}/${kubernetes_secret_v1.admin.metadata[0].name}" }
output "service_accounts" {
  value = {
    controller = "${var.namespaces.jenkins}/${kubernetes_service_account_v1.controller.metadata[0].name}"
    agent      = "${var.namespaces.agents}/${kubernetes_service_account_v1.agent.metadata[0].name}"
    deployer   = "${var.namespaces.agents}/${kubernetes_service_account_v1.deployer.metadata[0].name}"
  }
}
