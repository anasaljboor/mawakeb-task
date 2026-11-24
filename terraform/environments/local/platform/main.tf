locals {
  namespaces = {
    ingress    = { name = "traefik", level = "restricted" }
    jenkins    = { name = "jenkins", level = "restricted" }
    agents     = { name = "jenkins-agents", level = "privileged" }
    argocd     = { name = "argocd", level = "restricted" }
    app        = { name = "beacon", level = "restricted" }
    monitoring = { name = "monitoring", level = "restricted" }
  }
  hostnames = {
    app     = "beacon.${var.base_domain}"
    jenkins = "jenkins.${var.base_domain}"
    argocd  = "argocd.${var.base_domain}"
    grafana = "grafana.${var.base_domain}"
  }
  ns = module.namespaces.names
}

module "namespaces" {
  source               = "../../../modules/platform-namespaces"
  providers            = { kubernetes = kubernetes }
  namespaces           = local.namespaces
  pod_security_version = var.pod_security_version
  labels = {
    "app.kubernetes.io/part-of"    = "beacon-lab"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

module "ingress" {
  source              = "../../../modules/ingress-traefik"
  providers           = { helm = helm }
  namespace           = local.ns.ingress
  chart_version       = var.chart_versions.traefik
  service_type        = "NodePort"
  http_node_port      = var.ingress_http_node_port
  https_node_port     = var.ingress_https_node_port
  ingress_endpoint_ip = "127.0.0.1"
  service_annotations = {}
  node_selector       = { workload = "apps" }
}

module "argocd" {
  source             = "../../../modules/argocd"
  providers          = { kubernetes = kubernetes, helm = helm }
  namespaces         = { argocd = local.ns.argocd, app = local.ns.app }
  chart_version      = var.chart_versions.argocd
  apps_chart_version = var.chart_versions.argocd_apps
  hostname           = local.hostnames.argocd
  app_name           = "beacon"
  gitops_repo_url    = var.gitops_repo_url
  gitops_branch      = var.gitops_branch
  gitops_app_path    = var.gitops_app_path
  depends_on         = [module.ingress]
}

module "jenkins" {
  source    = "../../../modules/jenkins"
  providers = { kubernetes = kubernetes, helm = helm }
  namespaces = {
    jenkins = local.ns.jenkins
    agents  = local.ns.agents
    app     = local.ns.app
    argocd  = local.ns.argocd
  }
  chart_version     = var.chart_versions.jenkins
  image_tag         = var.jenkins_image_tag
  hostname          = local.hostnames.jenkins
  storage_class     = var.storage_class
  home_size         = "8Gi"
  trivy_cache_size  = "3Gi"
  git_repo_url      = var.git_repo_url
  git_branch        = var.git_branch
  registry_server   = var.registry_server
  registry_username = var.registry_username
  image_repo        = "${var.registry_server}/${var.registry_username}/beacon"
  app_hostname      = local.hostnames.app
  ingress_url       = module.ingress.service_url
  gitops_repo_url   = var.gitops_repo_url
  gitops_branch     = var.gitops_branch
  gitops_app_path   = var.gitops_app_path
  argocd_app_name   = "beacon"
  secrets_revision  = var.secrets_revision
  admin_password    = var.jenkins_admin_password
  registry_token    = var.registry_token
  gitops_token      = var.github_token
  depends_on        = [module.ingress]
}

module "observability" {
  source    = "../../../modules/observability"
  providers = { kubernetes = kubernetes, helm = helm }
  namespaces = {
    monitoring = local.ns.monitoring
    app        = local.ns.app
    ingress    = local.ns.ingress
  }
  log_namespaces                      = [local.ns.app, local.ns.jenkins, local.ns.agents, local.ns.argocd, local.ns.ingress]
  kube_prometheus_stack_chart_version = var.chart_versions.kube_prometheus_stack
  loki_chart_version                  = var.chart_versions.loki
  alloy_chart_version                 = var.chart_versions.alloy
  storage_class                       = var.storage_class
  prometheus_retention                = var.prometheus_retention
  grafana_hostname                    = local.hostnames.grafana
  secrets_revision                    = var.secrets_revision
  grafana_admin_password              = var.grafana_admin_password
  depends_on                          = [module.ingress]
}
