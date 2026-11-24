resource "azurerm_container_registry" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_role_assignment" "pull" {
  for_each                         = toset(var.pull_principal_ids)
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = each.value
  skip_service_principal_aad_check = true
}

resource "azurerm_container_registry_scope_map" "ci_push" {
  name                    = "ci-push"
  container_registry_name = azurerm_container_registry.this.name
  resource_group_name     = var.resource_group_name
  actions = flatten([
    for r in var.push_repositories : [
      "repositories/${r}/content/read",
      "repositories/${r}/content/write",
      "repositories/${r}/metadata/read",
    ]
  ])
}

resource "azurerm_container_registry_token" "ci_push" {
  name                    = "ci-push"
  container_registry_name = azurerm_container_registry.this.name
  resource_group_name     = var.resource_group_name
  scope_map_id            = azurerm_container_registry_scope_map.ci_push.id
}
