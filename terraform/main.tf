terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
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

provider "azuread" {}

# Reference the resource group created by the Bicep deployment.
data "azurerm_resource_group" "main" {
  name = "my-website-prod-rg"
}

# App Registration for ideas-api EasyAuth.
resource "azuread_application" "ideas_api" {
  display_name     = "ideas-api"
  sign_in_audience = "AzureADMyOrg"

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Access ideas-api on behalf of a user"
      admin_consent_display_name = "access_as_user"
      enabled                    = true
      id                         = "00000000-0000-0000-0000-000000000001"
      type                       = "User"
      user_consent_description   = "Access ideas-api on your behalf"
      user_consent_display_name  = "access_as_user"
      value                      = "access_as_user"
    }
  }
}

# Set identifier URI to api://{client_id} — must be done as a separate resource
# because the client_id is only known after the application is created.
resource "azuread_application_identifier_uri" "ideas_api" {
  application_id = azuread_application.ideas_api.id
  identifier_uri = "api://${azuread_application.ideas_api.client_id}"
}

resource "azuread_service_principal" "ideas_api" {
  client_id = azuread_application.ideas_api.client_id
}

resource "azuread_application_password" "ideas_api" {
  application_id = azuread_application.ideas_api.id
  display_name   = "terraform-managed"
  end_date       = "2099-01-01T00:00:00Z"
}

module "ideas_api" {
  source = "./modules/function_app"

  resource_group_name  = data.azurerm_resource_group.main.name
  location             = var.location
  app_name             = "ideas-api-prod"
  auth_tenant_id       = var.ideas_api_auth_tenant_id
  auth_client_id       = azuread_application.ideas_api.client_id
  auth_client_secret   = azuread_application_password.ideas_api.value
  secret_app_settings  = { IDEAS_WRITE_KEY = var.ideas_api_write_key }
}
