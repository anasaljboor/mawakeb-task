locals {
  namespaces = {
    ingress    = { name = "traefik", level = "restricted" }
    jenkins    = { name = "jenkins", level = "restricted" }
    agents     = { name = "jenkins-agents", level = "privileged" }
    argocd     = { name = "argocd", level = "restricted" }
    app        = { name = "beacon", level = "restricted" }
    monitoring = { name = "monitoring", level = "restricted" }
  }
  base_domain = var.base_domain != "" ? var.base_domain : "${var.ingress_public_ip}.nip.io"
  hostnames = {
    app     = "beacon.${local.base_domain}"
    jenkins = "jenkins.${local.base_domain}"
    argocd  = "argocd.${local.base_domain}"
    grafana = "grafana.${local.base_domain}"
  }
  ns = module.namespaces[0].names
}

resource "terraform_data" "input_guard" {
  input = var.deploy_platform
  lifecycle {
    precondition {
      condition = !var.deploy_platform || alltrue([
        var.resource_group_name != "", var.aks_name != "", var.key_vault_name != "",
        var.acr_login_server != "", var.ingress_public_ip != "", var.ingress_public_ip_name != "",
        var.git_repo_url != "", var.gitops_repo_url != "",
      ])
      error_message = "Copy the cluster stack outputs and the repository URLs into terraform.tfvars before deploy_platform=true."
    }
  }
}

data "azurerm_key_vault" "this" {
  count               = var.deploy_platform ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
  depends_on          = [terraform_data.input_guard]
}

ephemeral "azurerm_key_vault_secret" "platform" {
  for_each     = var.deploy_platform ? var.key_vault_secret_names : {}
  name         = each.value
  key_vault_id = data.azurerm_key_vault.this[0].id
}

module "namespaces" {
  count                = var.deploy_platform ? 1 : 0
  source               = "../../../modules/platform-namespaces"
  providers            = { kubernetes = kubernetes }
  namespaces           = local.namespaces
  pod_security_version = var.pod_security_version
  labels = {
    "app.kubernetes.io/part-of"    = "beacon"
    "app.kubernetes.io/managed-by" = "terraform"
  }
  depends_on = [terraform_data.input_guard]
}

module "ingress" {
  count               = var.deploy_platform ? 1 : 0
  source              = "../../../modules/ingress-traefik"
  providers           = { helm = helm }
  namespace           = local.ns.ingress
  chart_version       = var.chart_versions.traefik
  service_type        = "LoadBalancer"
  http_node_port      = 0
  https_node_port     = 0
  ingress_endpoint_ip = ""
  service_annotations = {
    "service.beta.kubernetes.io/azure-pip-name"                     = var.ingress_public_ip_name
    "service.beta.kubernetes.io/azure-load-balancer-resource-group" = var.resource_group_name
  }
  node_selector = { workload = "apps" }
}

module "argocd" {
  count              = var.deploy_platform ? 1 : 0
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
  count     = var.deploy_platform ? 1 : 0
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
  home_size         = "16Gi"
  trivy_cache_size  = "4Gi"
  git_repo_url      = var.git_repo_url
  git_branch        = var.git_branch
  registry_server   = var.acr_login_server
  registry_username = var.acr_ci_push_token
  image_repo        = "${var.acr_login_server}/beacon"
  app_hostname      = local.hostnames.app
  ingress_url       = module.ingress[0].service_url
  gitops_repo_url   = var.gitops_repo_url
  gitops_branch     = var.gitops_branch
  gitops_app_path   = var.gitops_app_path
  argocd_app_name   = "beacon"
  secrets_revision  = var.secrets_revision
  admin_password    = ephemeral.azurerm_key_vault_secret.platform["jenkins_admin_password"].value
  registry_token    = ephemeral.azurerm_key_vault_secret.platform["registry_token"].value
  gitops_token      = ephemeral.azurerm_key_vault_secret.platform["github_token"].value
  depends_on        = [module.ingress]
}

module "observability" {
  count     = var.deploy_platform ? 1 : 0
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
  grafana_admin_password              = ephemeral.azurerm_key_vault_secret.platform["grafana_admin_password"].value
  depends_on                          = [module.ingress]
}
