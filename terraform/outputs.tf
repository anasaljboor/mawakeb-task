
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

output "jenkins_url" {
  description = "Jenkins URL (through the ingress controller)"
  value       = "http://${var.jenkins_hostname}"
}

output "jenkins_admin_password_command" {
  description = "Command that prints the Jenkins admin password (the value itself is never output)"
  value       = "kubectl get secret ${kubernetes_secret_v1.jenkins_admin.metadata[0].name} -n ${local.ns_jenkins} -o jsonpath='{.data.jenkins-admin-password}' | base64 -d"
}

output "jenkins_chart_version" {
  description = "Deployed jenkins chart version"
  value       = helm_release.jenkins.version
}

output "ingress_class" {
  description = "IngressClass served by Traefik"
  value       = "traefik"
}
