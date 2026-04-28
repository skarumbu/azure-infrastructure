terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Reference the resource group created by the Bicep deployment.
data "azurerm_resource_group" "main" {
  name = "my-website-prod-rg"
}

module "ideas_api" {
  source = "./modules/function_app"

  resource_group_name  = data.azurerm_resource_group.main.name
  location             = var.location
  app_name             = "ideas-api-prod"
  auth_tenant_id       = var.ideas_api_auth_tenant_id
  auth_client_id       = var.ideas_api_auth_client_id
  auth_client_secret   = var.ideas_api_auth_client_secret
  secret_app_settings  = { IDEAS_WRITE_KEY = var.ideas_api_write_key }
}
