resources
| where type =~ 'microsoft.keyvault/vaults/certificates'
| where properties.vaultUri contains "your-key-vault-name"
| where properties.attributes.enabled == true
| project name, expiryDate = todatetime(properties.attributes.expires)
| extend daysRemaining = datetime_diff('day', expiryDate, now())
| order by daysRemaining asc
