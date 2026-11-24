output "id" { value = azurerm_container_registry.this.id }
output "login_server" { value = azurerm_container_registry.this.login_server }
output "ci_push_token_name" { value = azurerm_container_registry_token.ci_push.name }
