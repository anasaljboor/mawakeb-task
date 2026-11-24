locals {
  subnets = {
    aks = { address_prefixes = [cidrsubnet(var.vnet_cidr, 4, 0)] }
  }
  user_pools = {
    apps = {
      vm_size   = var.apps_vm_size
      min_count = 1
      max_count = 3
      zones     = var.zones
      labels    = { workload = "apps" }
      taints    = []
    }
    builds = {
      vm_size   = var.builds_vm_size
      min_count = 0
      max_count = 2
      zones     = var.zones
      labels    = { workload = "builds" }
      taints    = ["dedicated=builds:NoSchedule"]
    }
  }
  key_vault_secret_names = ["registry-token", "github-token", "jenkins-admin-password", "grafana-admin-password"]
}

resource "terraform_data" "input_guard" {
  input = var.deploy_azure
  lifecycle {
    precondition {
      condition = !var.deploy_azure || (
        var.subscription_id != "00000000-0000-0000-0000-000000000000" &&
        var.tenant_id != "00000000-0000-0000-0000-000000000000"
      )
      error_message = "Set the real subscription_id and tenant_id before deploy_azure=true."
    }
    precondition {
      condition     = !var.deploy_azure || (var.acr_name != "" && var.key_vault_name != "")
      error_message = "Choose globally unique acr_name and key_vault_name before deploy_azure=true."
    }
    precondition {
      condition     = !var.deploy_azure || length(var.admin_group_object_ids) > 0
      error_message = "Local accounts are disabled: supply at least one Entra admin group, or nobody can reach the cluster."
    }
    precondition {
      condition     = !var.deploy_azure || (length(var.admin_ip_ranges) > 0 && !contains(var.admin_ip_ranges, "0.0.0.0/0"))
      error_message = "Restrict the API server and Key Vault to explicit admin_ip_ranges; 0.0.0.0/0 is refused."
    }
    precondition {
      condition     = !var.deploy_azure || length(var.budget_contact_emails) > 0
      error_message = "Supply budget_contact_emails so cost alerts reach someone."
    }
  }
}

resource "azurerm_resource_group" "this" {
  count    = var.deploy_azure ? 1 : 0
  name     = var.name_prefix
  location = var.location
  tags     = var.tags

  depends_on = [terraform_data.input_guard]
}

resource "azurerm_log_analytics_workspace" "this" {
  count               = var.deploy_azure && var.create_log_analytics ? 1 : 0
  name                = "${var.name_prefix}-logs"
  location            = var.location
  resource_group_name = azurerm_resource_group.this[0].name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

module "network" {
  count                 = var.deploy_azure ? 1 : 0
  source                = "../../../modules/azure-network"
  providers             = { azurerm = azurerm }
  name                  = "${var.name_prefix}-vnet"
  location              = var.location
  resource_group_name   = azurerm_resource_group.this[0].name
  address_space         = [var.vnet_cidr]
  subnets               = local.subnets
  ingress_source_ranges = var.ingress_source_ranges
  tags                  = var.tags
}

module "aks" {
  count                    = var.deploy_azure ? 1 : 0
  source                   = "../../../modules/aks-cluster"
  providers                = { azurerm = azurerm }
  name                     = "${var.name_prefix}-aks"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this[0].name
  kubernetes_version       = var.kubernetes_version
  sku_tier                 = var.aks_sku_tier
  subnet_id                = module.network[0].subnet_ids["aks"]
  tenant_id                = var.tenant_id
  admin_group_object_ids   = var.admin_group_object_ids
  api_authorized_ip_ranges = var.admin_ip_ranges
  system_pool = {
    vm_size   = var.system_vm_size
    min_count = 1
    max_count = 3
    zones     = var.zones
  }
  user_pools                 = local.user_pools
  pod_cidr                   = "192.168.0.0/16"
  service_cidr               = "172.16.0.0/16"
  dns_service_ip             = "172.16.0.10"
  log_analytics_workspace_id = try(azurerm_log_analytics_workspace.this[0].id, "")
  tags                       = var.tags
}

resource "azurerm_public_ip" "ingress" {
  count               = var.deploy_azure ? 1 : 0
  name                = "${var.name_prefix}-ingress"
  location            = var.location
  resource_group_name = azurerm_resource_group.this[0].name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_ingress_ip" {
  count                = var.deploy_azure ? 1 : 0
  scope                = azurerm_public_ip.ingress[0].id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks[0].control_plane_principal_id
}

module "registry" {
  count               = var.deploy_azure ? 1 : 0
  source              = "../../../modules/container-registry"
  providers           = { azurerm = azurerm }
  name                = var.acr_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this[0].name
  sku                 = "Standard"
  pull_principal_ids  = [module.aks[0].kubelet_object_id]
  push_repositories   = ["beacon"]
  tags                = var.tags
}

module "key_vault" {
  count                        = var.deploy_azure ? 1 : 0
  source                       = "../../../modules/key-vault"
  providers                    = { azurerm = azurerm }
  name                         = var.key_vault_name
  location                     = var.location
  resource_group_name          = azurerm_resource_group.this[0].name
  tenant_id                    = var.tenant_id
  allowed_ip_ranges            = var.admin_ip_ranges
  secret_officer_principal_ids = var.operator_principal_ids
  secret_reader_principal_ids  = var.platform_reader_principal_ids
  tags                         = var.tags
}

module "budget" {
  count             = var.deploy_azure ? 1 : 0
  source            = "../../../modules/cost-budget"
  providers         = { azurerm = azurerm }
  name              = "${var.name_prefix}-monthly"
  resource_group_id = azurerm_resource_group.this[0].id
  monthly_amount    = var.budget_monthly_amount
  start_date        = var.budget_start_date
  contact_emails    = var.budget_contact_emails
}
