resource "terraform_data" "input_guard" {
  input = var.deploy_azure
  lifecycle {
    precondition {
      condition = !var.deploy_azure || (
        var.subscription_id != "00000000-0000-0000-0000-000000000000" &&
        var.tenant_id != "00000000-0000-0000-0000-000000000000" &&
        var.storage_account_name != ""
      )
      error_message = "Set subscription_id, tenant_id and a globally unique storage_account_name before deploy_azure=true."
    }
    precondition {
      condition     = !var.deploy_azure || (length(var.state_writer_principal_ids) > 0 && length(var.admin_ip_ranges) > 0 && !contains(var.admin_ip_ranges, "0.0.0.0/0"))
      error_message = "Supply the principals that run Terraform and explicit admin_ip_ranges; 0.0.0.0/0 is refused."
    }
  }
}

module "state_storage" {
  count                      = var.deploy_azure ? 1 : 0
  source                     = "../../../modules/state-storage"
  providers                  = { azurerm = azurerm }
  resource_group_name        = var.resource_group_name
  location                   = var.location
  storage_account_name       = var.storage_account_name
  container_name             = "tfstate"
  allowed_ip_ranges          = var.admin_ip_ranges
  state_writer_principal_ids = var.state_writer_principal_ids
  retention_days             = var.retention_days
  tags                       = var.tags
  depends_on                 = [terraform_data.input_guard]
}
