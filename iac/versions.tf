terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.22.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "2.2.0"
    }
  }
}
