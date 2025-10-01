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

=========================for all response code=====================
let window = 14d;    // history length
let step = 5m;       // evaluation granularity
ApiManagementGatewayLogs
| where TimeGenerated > ago(window)
| where IsRequestSuccess == false
| where ResponseCode in (400,401,409,422,429,500,503)
| where ApiId == "fs-portfolio-accounting"
| summarize Failures = count() by ResponseCode, bin(TimeGenerated, step)
| make-series Failures = avg(Failures) on TimeGenerated 
        from ago(window) to now() step step 
        by ResponseCode
| extend (anomalies, score, baseline) = series_decompose_anomalies(Failures, 1.5, -1, "linefit")
| mv-expand TimeGenerated, Failures, anomalies, ResponseCode
| where anomalies == 1


detatails:
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



Client Requirement (per attached screenshots):

Client has requested log-based alerts with static thresholds for the fs-portfolio-accounting API.

Each HTTP response code must have its own static threshold condition:

Response Code	Threshold (Static)	Notes
400 – Bad Request	Alert if >20 / hour	Throttle at hourly window
401 – Unauthorized	Alert on every response	Each occurrence
409 – Conflict	Alert on every response	Each occurrence
422 – Unprocessable Content	Alert if >20 / hour	Hourly aggregation
429 – Too Many Requests	Alert on every response	Each occurrence
500 – Internal Server Error	Alert if >5 / minute	High sensitivity
503 – Service Unavailable	Alert on every response	Each occurrence

Notifications must route via PagerDuty (DEV and DEV/ASG groups as mapped in client’s table).

Essentially, the client expects 7 separate static alert rules based on different error codes and thresholds.

Our Implementation Approach:

Instead of static thresholds, we are implementing dynamic anomaly detection alerts using KQL functions like series_decompose_anomalies().

Why dynamic?

Smarter detection: Uses 14 days of history to learn baseline patterns per error code.

Noise reduction: Avoids firing alerts for routine background failures (e.g., normal 401 login errors).

Future-proof: Automatically adjusts as traffic grows, unlike fixed 20/hr or 5/min rules that require manual tuning.

Focus on real issues: Ensures PagerDuty only gets notified when error rates deviate significantly from the learned baseline (true anomalies).

Next Steps:

Configure dynamic alert queries for response codes 400, 401, 409, 422, 429, 500, 503.

Single query can handle all codes with ResponseCode dimension, but we may split per code if we need different sensitivities (e.g., reduce noise on 401 while keeping 500/503 strict).

Deliver initial setup in Azure Monitor → Log Alerts, with anomaly-based detection and action groups to PagerDuty.



#!/bin/ksh
set -o errexit
set -o pipefail
set -o nounset

PRIVATE_KEY_FILE_NAME=private_key.pem
PUBLIC_CERT_FILE_NAME=public_key.cer
PRIVATE_DER_FILE_NAME=private_key.der

echo "🔑 Creating new certificates..."
cd $(mktemp -d)

# Generate private key
openssl genrsa -out $PRIVATE_KEY_FILE_NAME 4096

# Convert to DER format
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in $PRIVATE_KEY_FILE_NAME -out $PRIVATE_DER_FILE_NAME -nocrypt

# Create self-signed public cert (200 days validity)
openssl req -new -x509 -key $PRIVATE_KEY_FILE_NAME \
  -out $PUBLIC_CERT_FILE_NAME -days 200 -sha512 -subj "/CN=myapp"

# Cleanup handler
removeCertsOnExit() {
    echo "🧹 Removing temporary cert files"
    rm -f $PUBLIC_CERT_FILE_NAME
    rm -f $PRIVATE_KEY_FILE_NAME
    rm -f $PRIVATE_DER_FILE_NAME
}
trap 'removeCertsOnExit' ERR

echo "✅ Certificates generated:"
ls -l $PRIVATE_KEY_FILE_NAME $PRIVATE_DER_FILE_NAME $PUBLIC_CERT_FILE_NAME

# === SSQ Upload (still kept) ===
echo "⬆️ Uploading keys to SCV/SSQ"

# Upload Public Cert
ssq put-key-version $SCV_NAMESPACE "$SCV_PUBLIC_KEY" set_current=1 keep_last=3 < $PUBLIC_CERT_FILE_NAME

# Upload Private PEM (if defined)
if [ -n "${SCV_PRIVATE_KEY:-}" ] ; then
    ssq put-key-version $SCV_NAMESPACE "$SCV_PRIVATE_KEY" set_current=1 keep_last=3 < $PRIVATE_KEY_FILE_NAME
fi

# Upload Private DER (if defined)
if [ -n "${SCV_PRIVATE_DER:-}" ] ; then
    cat $PRIVATE_DER_FILE_NAME | ssq put-key-version $SCV_NAMESPACE $SCV_PRIVATE_DER set_current=1 keep_last=3
fi

echo "🎯 Done. Upload $PUBLIC_CERT_FILE_NAME manually in Azure Portal."

