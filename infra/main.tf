# 1. Create the Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project     = var.project_name
    environment = "dev"
    managed_by  = "terraform"
  }
}

# 2. Log Analytics for Monitoring
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-secure-b2b-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 3. Create a User Assigned Identity (The Passport)
# We create this first so it can have permissions BEFORE the app starts
resource "azurerm_user_assigned_identity" "containerapp_id" {
  name                = "id-secure-b2b-api"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# 4. Container Registry (The Warehouse)
resource "random_string" "acr_suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_container_registry" "acr" {
  name                = "acrsecureb2b${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = false
}

# 5. GIVE PERMISSION FIRST
# This gives the "Passport" permission to pull images from the "Warehouse"
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.containerapp_id.principal_id
}

# 6. Container App Environment (The Neighborhood)
resource "azurerm_container_app_environment" "env" {
  name                       = "cae-secure-b2b-api"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

# 7. Deploy the Container App (The House)
resource "azurerm_container_app" "api" {
  name                         = "ca-secure-b2b-api"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  # Use the identity we created earlier
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp_id.id]
  }

  template {
    container {
      name   = "secure-b2b-api"
      image  = "${azurerm_container_registry.acr.login_server}/secure-b2b-api:dev"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "ENVIRONMENT"
        value = "dev"
      }
    }
    min_replicas = 1
    max_replicas = 3
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Tell the app to use the User Identity to talk to the Registry
  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp_id.id
  }

  # This ensures the permission is actually active before Azure tries to pull the image
  depends_on = [
    azurerm_role_assignment.acr_pull
  ]
}


resource "azurerm_api_management" "apim" {
  name                = "apim-secure-b2b-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Secure B2B Platform"
  publisher_email     = "admin@secureb2b.local"
  sku_name            = "Developer_1" // no moeny for premium

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "dev"
    project     = "secure-b2b-api"
    managed_by  = "terraform"
  }
}

resource "azurerm_api_management_api" "order_api" {
  name                = "order-backend-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Secure Order API"
  path                = "orders"
  protocols           = ["https"]

  service_url = "https://ca-secure-b2b-api.kinddesert-728a0a44.germanywestcentral.azurecontainerapps.io"
}

//creating the product - multiple APIs
resource "azurerm_api_management_product" "partner_product" {
  product_id            = "partner-product"
  api_management_name   = azurerm_api_management.apim.name
  resource_group_name   = azurerm_resource_group.rg.name
  display_name          = "Partner Order API"
  subscription_required = true
  approval_required     = false
  published             = true
}

//product
resource "azurerm_api_management_product_api" "product_api_link" {
  api_name            = azurerm_api_management_api.order_api.name
  product_id          = azurerm_api_management_product.partner_product.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
}
// partner key for the product
resource "azurerm_api_management_subscription" "partner_subscription" {
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  display_name = "Partner Access Subscription"
  product_id   = azurerm_api_management_product.partner_product.id
  state        = "active"
}
//apim health OK 404
resource "azurerm_api_management_api_operation" "health" {
  operation_id        = "health"
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  display_name = "Health Check"
  method       = "GET"
  url_template = "/health"

  response {
    status_code = 200
  }
}



# Monitoring 

resource "azurerm_monitor_diagnostic_setting" "apim_diag" {
  name                       = "diag-apim-secure-b2b"
  target_resource_id         = azurerm_api_management.apim.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_log {
    category = "DeveloperPortalAuditLogs"
  }

  enabled_log {
    category = "WebSocketConnectionLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "cae_diag" {
  name                       = "diag-cae-secure-b2b"
  target_resource_id         = azurerm_container_app_environment.env.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "containerapp_diag" {
  name                       = "diag-ca-secure-b2b"
  target_resource_id         = azurerm_container_app.api.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}


//rate limiting
resource "azurerm_api_management_api_policy" "order_api_policy" {
  api_name            = azurerm_api_management_api.order_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />

    <!-- Rate limiting -->
    <rate-limit-by-key 
        calls="100"
        renewal-period="60"
        counter-key="@(context.Subscription.Id)" />

  </inbound>

  <backend>
    <base />
  </backend>

  <outbound>
    <base />
  </outbound>

  <on-error>
    <base />
  </on-error>
</policies>
XML
}