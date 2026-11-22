
output "namespaces" {
  description = "Namespaces created for the lab"
  value       = { for k, ns in kubernetes_namespace_v1.this : k => ns.metadata[0].name }
}

output "service_accounts" {
  description = "Service accounts and where they live"
  value = {
    jenkins_controller = "${local.ns_jenkins}/${kubernetes_service_account_v1.jenkins.metadata[0].name}"
    build_agent        = "${local.ns_agents}/${kubernetes_service_account_v1.agent.metadata[0].name}"
    deployer           = "${local.ns_agents}/${kubernetes_service_account_v1.deployer.metadata[0].name}"
  }
}
