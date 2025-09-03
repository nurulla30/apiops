AzureDiagnostics
| where ResourceType == "VAULTS"
| where OperationName == "CertificateNearExpiryEventGridNotification"
| extend CertExpire = unixtime_seconds_todatetime(eventGridEventProperties_data_EXP_d)
| extend DaysTillExpire = datetime_diff("day", CertExpire, now())
| project TimeGenerated, ResourceId, eventGridEventProperties_subject_s, CertExpire, DaysTillExpire
