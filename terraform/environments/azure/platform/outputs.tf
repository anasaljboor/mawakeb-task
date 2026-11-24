output "urls" {
  value = var.deploy_platform ? {
    app     = "http://${local.hostnames.app}"
    jenkins = module.jenkins[0].url
    argocd  = module.argocd[0].url
    grafana = module.observability[0].grafana_url
  } : null
}
