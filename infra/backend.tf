terraform {
  backend "azurerm" {
    resource_group_name  = "rg-azureshop-dev"
    storage_account_name = "myprojectazshoptfstate"
    container_name       = "tfstate"
    # key is NOT hardcoded here — it is passed per environment:
    # terraform init -backend-config="environments/dev/backend.hcl"
    # terraform init -backend-config="environments/staging/backend.hcl"
    # terraform init -backend-config="environments/prod/backend.hcl"
  }
}
