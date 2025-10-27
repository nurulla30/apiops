locals {
  action_groups = { for ag in var.action_groups : ag.name => ag }
  alerts        = { for a in var.alert_definitions : a.name => a }
}

# === Create all Action Groups ===
resource "azurerm_monitor_action_group" "this" {
  for_each            = local.action_groups
  name                = each.value.name
  resource_group_name = var.resource_group_name
  short_name          = each.value.short_name

  webhook_receiver {
    name                    = each.value.webhook_name
    service_uri             = each.value.webhook_uri
    use_common_alert_schema = each.value.use_common_alert_schema
  }

  tags = each.value.tags
}

# === Create all Log Alerts ===
resource "azurerm_monitor_scheduled_query_rules_alert" "this" {
  for_each            = local.alerts
  name                = each.value.name
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = each.value.description
  severity            = each.value.severity
  enabled             = true
  data_source_id      = var.data_source_id

  frequency   = each.value.frequency
  time_window = each.value.time_window

  # Dynamically link to one or more action groups by name
  action {
    action_group = [
      for ref in each.value.action_group_refs :
      azurerm_monitor_action_group.this[ref].id
    ]
  }

  query = each.value.query

  trigger {
    operator  = "GreaterThanOrEqual"
    threshold = each.value.threshold
  }

  tags = each.value.tags
}
