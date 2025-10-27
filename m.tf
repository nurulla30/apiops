provider "azurerm" {
  features {}
}

module "monitoring" {
  source = "./modules/monitor"

  resource_group_name = var.resource_group_name
  location            = var.location
  data_source_id      = var.data_source_id
  action_groups       = var.action_groups
  alert_definitions   = var.alert_definitions
}
