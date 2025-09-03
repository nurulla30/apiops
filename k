AzureDiagnostics
| where ResourceType == "VAULTS"
| where OperationName == "CertificateNearExpiryEventGridNotification"
| extend CertExpire = unixtime_seconds_todatetime(eventGridEventProperties_data_EXP_d)
| extend CertName   = eventGridEventProperties_subject_s
| summarize arg_max(TimeGenerated, CertExpire) by ResourceId, CertName
| extend DaysTillExpire = datetime_diff("day", CertExpire, now())
| project ResourceId, CertName, CertExpire, DaysTillExpire
