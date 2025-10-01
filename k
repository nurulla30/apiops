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


This KQL query is designed to detect unusual spikes in 401 Unauthorized errors for the fs-portfolio-accounting API.
Instead of firing an alert every time a 401 occurs, it uses anomaly detection to only alert when the number of 401s is abnormal compared to the historical baseline.

🔹 Step-by-Step Breakdown

Lookback window

let window = 14d;   // how much history to analyze
let step = 5m;      // granularity of evaluation


The query analyzes the past 14 days of data.

It groups failures into 5-minute buckets.

Filter for 401 failures

| where IsRequestSuccess == false
| where ResponseCode == 401
| where ApiId == "fs-portfolio-accounting"


Only includes failed requests with HTTP 401 Unauthorized.

Focuses only on the fs-portfolio-accounting API.

Summarize counts per time bucket

| summarize Failures = count() by bin(TimeGenerated, step)


Counts how many 401s happened in each 5-minute interval.

Build a time series

| make-series Failures = avg(Failures) on TimeGenerated


Creates a continuous time series of 401 failures, even if some intervals had none.

Detect anomalies

| extend (anomalies, score, baseline) = series_decompose_anomalies(Failures, 1.5, -1, "linefit")


Applies Azure’s series_decompose_anomalies() function.

It learns the normal pattern of 401s over time.

If the count deviates significantly (based on sensitivity 1.5), it marks it as an anomaly.

Expand results and filter anomalies

| mv-expand TimeGenerated, Failures, anomalies
| where anomalies == 1


Expands the time series into rows.

Keeps only those time intervals where an anomaly was detected.

🔹 What This Means in Practice

Static threshold (old way): “Alert if ≥1 401 error in 5 minutes.” → noisy, fires often.

Dynamic anomaly detection (new way): “Alert only if the number of 401s is unusually high compared to the last 14 days.” → smarter, fewer false positives.

Example:

If you normally see ~5 bad logins per 5 minutes, that becomes the baseline → no alert.

If you suddenly see 200 bad logins in 5 minutes, the anomaly detector flags it → alert fires.

✅ Value for the Team

Less noise: avoids unnecessary alerts for normal background failures.

More signal: surfaces genuine issues (misconfigured client, mass login failures, security incidents).

Data-driven thresholds: adjusts automatically as traffic patterns change, without needing manual re-tuning.
