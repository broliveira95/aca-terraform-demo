provider "azapi" {}

provider "azurerm" {
  features {}
}

locals {
  resource_group_name = "rg-self-hosted-llm-demo"
  location            = "swedencentral"
  container_image     = "ghcr.io/open-webui/open-webui:ollama"
}

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = local.location
}

# RESOURCES
# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-self-hosted-llm-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}

# Create virtual network
resource "azurerm_subnet" "snet" {
  name                 = "snet-self-hosted-llm-demo"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.4.0/23"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_storage_account" "sa" {
  name                     = "saselfhostedllmdemo"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# # Create Container App environment
resource "azapi_resource" "cae" {
  type      = "Microsoft.App/managedEnvironments@2024-03-01"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  name      = "cae-self-hosted-llm-demo"
  body = {
    properties = {
      vnetConfiguration = {
        infrastructureSubnetId = azurerm_subnet.snet.id
        internal               = false
      }
      workloadProfiles = [
        {
          name                = "Consumption",
          workloadProfileType = "Consumption",
        },
        {
          name                = "NC8as-T4",
          workloadProfileType = "Consumption-GPU-NC8as-T4",
        }
      ]
    }
  }
}


# Deploy Azure Container App
resource "azurerm_container_app" "ca" {
  name                         = "ca-self-hosted-llm-demo"
  container_app_environment_id = azapi_resource.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "aca-demo-container"
      image  = local.container_image
      cpu    = 8
      memory = "56Gi"
    }

    min_replicas = 0
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  workload_profile_name = "NC8as-T4"
}
