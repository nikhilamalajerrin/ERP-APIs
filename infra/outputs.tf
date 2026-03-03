output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.law.id
}

output "log_analytics_workspace_workspace_id" {
  value = azurerm_log_analytics_workspace.law.workspace_id
}

output "log_analytics_primary_shared_key" {
  value     = azurerm_log_analytics_workspace.law.primary_shared_key
  sensitive = true
}

output "acr_id" {
  value = azurerm_container_registry.acr.id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "apim_gateway_url" {
  value = azurerm_api_management.apim.gateway_url
}

output "apim_name" {
  value = azurerm_api_management.apim.name
}

output "apim_resource_group" {
  value = azurerm_resource_group.rg.name
}
output "partner_subscription_key" {
  value     = azurerm_api_management_subscription.partner_subscription.primary_key
  sensitive = true
}