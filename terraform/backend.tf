# Remote state stored in the same Azure Blob Storage account as discord-bot-infra.
# Run once before first apply:
#   az storage account create --name discordbottfstate --resource-group tfstate-rg --sku Standard_LRS
#   az storage container create --name tfstate --account-name discordbottfstate
# Then: terraform init

terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "discordbottfstate"
    container_name       = "tfstate"
    key                  = "azure-infrastructure/prod/terraform.tfstate"
  }
}
