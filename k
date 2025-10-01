let window = 14d;   // how much history to analyze
let step = 5m;      // granularity of evaluation
ApiManagementGatewayLogs
| where TimeGenerated > ago(window)
| where IsRequestSuccess == false
| where ResponseCode == 401
| where ApiId == ""
| summarize Failures = count() by bin(TimeGenerated, step)
| make-series Failures = avg(Failures) on TimeGenerated
      from ago(window) to now() step step
| extend (anomalies, score, baseline) = series_decompose_anomalies(Failures, 1.5, -1, "linefit")
| mv-expand TimeGenerated to typeof(datetime),
            Failures to typeof(long),
            anomalies to typeof(int)
| where anomalies == 1
