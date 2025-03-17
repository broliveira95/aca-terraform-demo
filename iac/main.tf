provider "azurerm" {
  features {}
  subscription_id = "605b660f-cb17-4f42-b14e-d6fb72627360"
}

locals {  
  resource_group_name = "rg-self-hosted-llm-demo"
  location            = "swedencentral"
  # container_image     = "ghcr.io/open-webui/open-webui:ollama"
  container_image     = "nginx:latest"
}

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = local.location
}

# RESOURCES
# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-azugot-aiaca-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Create virtual network
resource "azurerm_subnet" "snet" {
  name                 = "snet-azugot-aiaca-demo"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Container App environment
resource "azurerm_container_app_environment" "cae" {
  name                           = "cae-aca-demo"
  location                       = azurerm_resource_group.rg.location
  resource_group_name            = azurerm_resource_group.rg.name
  infrastructure_subnet_id       = azurerm_subnet.snet.id
  internal_load_balancer_enabled = false
}

# resource "azapi_resource_action" "cae_patch" {
#   type        = "Microsoft.App/managedEnvironments@2024-03-01"
#   resource_id = module.container_app_environment.id
#   method      = "PATCH"
#   body = {
#     properties = {
#       workloadProfiles = [
#         # {
#         #   name                = "Consumption",
#         #   workloadProfileType = "Consumption",
#         # },
#         {
#           name                = "NC8as-T4",
#           workloadProfileType = "Consumption-GPU-NC8as-T4",
#         }
#       ]
#     }
#   }
# }


# Deploy Azure Container App
resource "azurerm_container_app" "ca" {
  name                         = "ca-azugot-aiaca-demo"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "aca-demo-container"
      image  = local.container_image
      cpu    = 4
      memory = "8Gi"
    }

    min_replicas = 0
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      latest_revision = true
      percentage = 100
    }
  }
}