output "backend_config" {
  description = "Values for backend.azurerm.tf in the cluster and platform stacks."
  value = var.deploy_azure ? {
    resource_group_name  = module.state_storage[0].resource_group_name
    storage_account_name = module.state_storage[0].storage_account_name
    container_name       = module.state_storage[0].container_name
    use_azuread_auth     = true
  } : null
}
