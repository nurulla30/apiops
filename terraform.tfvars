resource_group_name = "eon72372-use2-prod1-isg01-rg"
location            = "East US 2"

data_source_id = "/subscriptions//resourceGroups//providers/Microsoft.ApiManagement/service/"

# === Action Groups ===
action_groups = [
  {
    name                    = "ag-pagerduty-5xx"
    short_name              = "Apli5xx"
    webhook_name            = "PagerDuty 5xx"
    webhook_uri             = "https://events.pagerduty.com/x-ere/KEYFOR5XX"
    use_common_alert_schema = false
    tags                    = { type = "pagerduty", severity = "critical" }
  },
  {
    name                    = "ag-pagerduty-503"
    short_name              = "Apli503"
    webhook_name            = "PagerDuty 503"
    webhook_uri             = "https://events.pagerduty.com/x-ere/KEYFOR503"
    use_common_alert_schema = false
    tags                    = { type = "pagerduty", severity = "warning" }
  },
  {
    name                    = "ag-teams-notify"
    short_name              = "TeamsNt"
    webhook_name            = "Teams Webhook"
    webhook_uri             = "https://outlook.office.com/webhook/XYZ"
    use_common_alert_schema = false
    tags                    = { type = "teams", severity = "info" }
  }
]

# === Log Alerts ===
alert_definitions = [
  {
    name               = "APIM Backend 5xx Alert"
    description        = "Triggers when 5xx backend errors exceed 12 in 1h"
    threshold          = 12
    severity           = 1
    frequency          = "PT1H"
    time_window        = "PT1H"
    action_group_refs  = ["ag-pagerduty-5xx", "ag-teams-notify"]
    tags               = { alert = "backend5xx", env = "prod" }

    query = <<-QUERY
      ApiManagementGatewayLogs
      | where TimeGenerated > ago(1h)
      | where ISRequestSuccess == false
      | where BackendResponseCode >= 500
      | project TimeGenerated, ApiId, Url, ResponseCode, BackendUrl, BackendResponseCode
    QUERY
  },
  {
    name               = "APIM Backend 503 Alert"
    description        = "Triggers when 503 errors exceed 5 in 1h"
    threshold          = 5
    severity           = 2
    frequency          = "PT1H"
    time_window        = "PT1H"
    action_group_refs  = ["ag-pagerduty-503", "ag-teams-notify"]
    tags               = { alert = "backend503", env = "prod" }

    query = <<-QUERY
      ApiManagementGatewayLogs
      | where TimeGenerated > ago(1h)
      | where ISRequestSuccess == false
      | where BackendResponseCode == 503
      | project TimeGenerated, ApiId, Url, ResponseCode, BackendUrl, BackendResponseCode
    QUERY
  }
]
