AzureDiagnostics
| where ResourceType == "VAULTS" 
| where OperationName == "CertificateNearExpiryEventGridNotification"
| extend
    CertExpire = unixtime_seconds_todatetime(eventGridEventProperties_data_EXP_d),
    CertIssue  = unixtime_seconds_todatetime(eventGridEventProperties_data_NBF_d),
    CertName   = eventGridEventProperties_subject_s
| where CertName == ""   // 👈 filter by your KV cert name
| summarize arg_max(CertExpire, CertIssue, *) by CertName, ResourceId
| extend DaysTillExpire = datetime_diff("day", CertExpire, now())
| project ResourceId, CertName, DaysTillExpire, CertExpire, CertIssue
