variable "resource_group_name" {}
variable "location" { default = "East US 2" }
variable "data_source_id" {}

variable "action_groups" {
  description = "List of Action Groups to create"
  type = list(object({
    name                    = string
    short_name               = string
    webhook_name             = string
    webhook_uri              = string
    use_common_alert_schema  = bool
    tags                     = map(string)
  }))
}

variable "alert_definitions" {
  description = "List of log alerts to create"
  type = list(object({
    name               = string
    description        = string
    threshold          = number
    severity           = number
    frequency          = string
    time_window        = string
    query              = string
    action_group_refs  = list(string)  # refers to action_group.name values
    tags               = map(string)
  }))
}
