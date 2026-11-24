provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  features {}
}

data "azurerm_kubernetes_cluster" "this" {
  count               = var.deploy_platform ? 1 : 0
  name                = var.aks_name
  resource_group_name = var.resource_group_name
}

locals {
  aks_host = try(data.azurerm_kubernetes_cluster.this[0].kube_config[0].host, "https://localhost")
  aks_ca   = try(base64decode(data.azurerm_kubernetes_cluster.this[0].kube_config[0].cluster_ca_certificate), "")
  kubelogin = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
  }
}

provider "kubernetes" {
  host                   = local.aks_host
  cluster_ca_certificate = local.aks_ca
  exec {
    api_version = local.kubelogin.api_version
    command     = local.kubelogin.command
    args        = local.kubelogin.args
  }
}

provider "helm" {
  kubernetes = {
    host                   = local.aks_host
    cluster_ca_certificate = local.aks_ca
    exec = {
      api_version = local.kubelogin.api_version
      command     = local.kubelogin.command
      args        = local.kubelogin.args
    }
  }
}
