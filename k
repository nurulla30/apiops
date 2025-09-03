Resources
| where type == "microsoft.keyvault/vaults/certificates/versions"
| extend CertName = name
| extend ExpirationDate = todatetime(properties.attributes.expires)
| extend DaysTillExpire = datetime_diff("day", ExpirationDate, now())
| where CertName == ""  // your cert name
| project subscriptionId, resourceGroup, CertName, ExpirationDate, DaysTillExpire
