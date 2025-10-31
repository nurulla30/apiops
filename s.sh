#!/bin/bash
set -e

# ==============================
# CONFIGURATION
# ==============================
# Define SPN and Key Vault details per environment
declare -A CLIENT_IDS=(
  [dev]="11111111-1111-1111-1111-111111111111"
  [qa]="22222222-2222-2222-2222-222222222222"
  [prod]="33333333-3333-3333-3333-333333333333"
)


declare -A SUBSCRIPTIONS=(
  [dev]="sub-dev-xxxx"
  [qa]="sub-qa-yyyy"
  [prod]="sub-prod-zzzz"
)

declare -A KEYVAULT_NAMES=(
  [dev]="my-dev-kv"
  [qa]="my-qa-kv"
  [prod]="my-prod-kv"
)

# Shared tenant ID for all environments
TENANT_ID=""

# ==============================
# ENVIRONMENT SELECTION
# ==============================
echo "Select environment:"
select ENV in dev qa prod; do
  if [[ -n "$ENV" ]]; then
    echo "Selected: $ENV"
    break
  else
    echo "Invalid choice, try again."
  fi
done

# ==============================
# SPN LOGIN (secure password)
# ==============================
echo -n "Enter SPN password for environment '$ENV': "
read -s SPN_PASSWORD
echo ""

echo "Logging into Azure using Service Principal..."
az login --service-principal \
  --username "${CLIENT_IDS[$ENV]}" \
  --password "$SPN_PASSWORD" \
  --tenant "$TENANT_ID" > /dev/null

az account set --subscription "${SUBSCRIPTIONS[$ENV]}"
echo "Logged in as SPN for $ENV"

# ==============================
# ACTION SELECTION
# ==============================
echo "What would you like to do?"
select ACTION in "Add new secret" "Rotate existing secret"; do
  if [[ "$ACTION" == "Add new secret" || "$ACTION" == "Rotate existing secret" ]]; then
    echo "Selected: $ACTION"
    break
  else
    echo "Invalid choice, try again."
  fi
done

KV_NAME="${KEYVAULT_NAMES[$ENV]}"

# ==============================
# ADD NEW SECRET
# ==============================
if [[ "$ACTION" == "Add new secret" ]]; then
  echo -n "Enter new secret name: "
  read SECRET_NAME

  echo -n "Enter secret value (hidden): "
  read -s SECRET_VALUE
  echo ""

  echo "Creating new secret '$SECRET_NAME' in Key Vault '$KV_NAME'..."
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "$SECRET_NAME" \
    --value "$SECRET_VALUE" > /dev/null

  echo "Secret '$SECRET_NAME' successfully created in $KV_NAME ($ENV)."
fi

# ==============================
# ROTATE EXISTING SECRET
# ==============================
if [[ "$ACTION" == "Rotate existing secret" ]]; then
  echo "Fetching existing secrets from Key Vault '$KV_NAME'..."
  SECRET_LIST=$(az keyvault secret list --vault-name "$KV_NAME" --query "[].name" -o tsv)

  if [[ -z "$SECRET_LIST" ]]; then
    echo "No secrets found in Key Vault '$KV_NAME'."
    exit 0
  fi

  echo "Select a secret to rotate:"
  select SECRET_NAME in $SECRET_LIST; do
    if [[ -n "$SECRET_NAME" ]]; then
      echo "Selected secret: $SECRET_NAME"
      break
    else
      echo "Invalid choice, try again."
    fi
  done

  echo -n "Enter new value for '$SECRET_NAME' (hidden): "
  read -s NEW_VALUE
  echo ""

  echo "Rotating secret '$SECRET_NAME' in Key Vault '$KV_NAME'..."
  az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "$SECRET_NAME" \
    --value "$NEW_VALUE" > /dev/null

  echo "Secret '$SECRET_NAME' successfully rotated in $KV_NAME ($ENV)."
fi

# ==============================
# CLEANUP
# ==============================
echo "Logging out..."
az logout > /dev/null
unset SPN_PASSWORD
echo "Done."
