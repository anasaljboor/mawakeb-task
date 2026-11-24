output "urls" {
  value = {
    app     = "http://${local.hostnames.app}"
    jenkins = module.jenkins.url
    argocd  = module.argocd.url
    grafana = module.observability.grafana_url
  }
}
output "namespaces" { value = local.ns }
output "service_accounts" { value = merge(module.jenkins.service_accounts, { argocd_sync = module.argocd.sync_service_account }) }
output "password_commands" {
  description = "Copy each admin password to the clipboard; values are never output."
  value = {
    jenkins = "kubectl get secret jenkins-admin -n ${local.ns.jenkins} -o jsonpath='{.data.jenkins-admin-password}' | base64 -d | pbcopy"
    argocd  = "kubectl get secret argocd-initial-admin-secret -n ${local.ns.argocd} -o jsonpath='{.data.password}' | base64 -d | pbcopy"
    grafana = "kubectl get secret grafana-admin -n ${local.ns.monitoring} -o jsonpath='{.data.admin-password}' | base64 -d | pbcopy"
  }
}
