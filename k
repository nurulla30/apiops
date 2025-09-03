resources
| where type =~ 'microsoft.keyvault/vaults/certificates'
| where properties.vaultUri contains "your-key-vault-name"
| where properties.attributes.enabled == true
| project name, expiryDate = todatetime(properties.attributes.expires), tags
| extend daysRemaining = datetime_diff('day', expiryDate, now())
| where daysRemaining > 0 // Optional: Only show certificates that have not yet expired
| order by daysRemaining asc
