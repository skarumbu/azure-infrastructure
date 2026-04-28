terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Short stable suffix so storage account name stays under 24 chars and is globally unique.
resource "random_id" "suffix" {
  byte_length = 4
  keepers = {
    resource_group = var.resource_group_name
    app_name       = var.app_name
  }
}

locals {
  storage_name = lower(replace("${var.app_name}${random_id.suffix.hex}", "-", ""))
}

resource "azurerm_storage_account" "main" {
  name                     = local.storage_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_table" "ideas" {
  name                 = "ideas"
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                       = var.app_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  site_config {
    application_stack {
      python_version = var.python_version
    }
    cors {
      allowed_origins = ["*"]
    }
  }

  app_settings = merge(var.app_settings, var.secret_app_settings, {
    IDEAS_TABLE_CONNECTION_STRING            = azurerm_storage_account.main.primary_connection_string
    MICROSOFT_PROVIDER_AUTHENTICATION_SECRET = var.auth_client_secret
  })

  auth_settings_v2 {
    auth_enabled           = true
    unauthenticated_action = "Return401"
    default_provider       = "azureactivedirectory"

    active_directory_v2 {
      client_id                  = var.auth_client_id
      client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
      tenant_auth_endpoint       = "https://sts.windows.net/${var.auth_tenant_id}/v2.0"
      allowed_audiences          = ["api://${var.auth_client_id}"]
    }

    login {
      token_store_enabled = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
