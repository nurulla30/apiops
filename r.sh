#!/bin/bash
set -e

# ==============================
# CONFIGURATION
# ==============================
# Key Vaults and subscriptions per environment
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

KV_NAME="${KEYVAULT_NAMES[$ENV]}"
SUBSCRIPTION_ID="${SUBSCRIPTIONS[$ENV]}"

# ==============================
# LOGIN AS USER
# ==============================
echo "Logging in with your Azure user account..."
az login --use-device-code > /dev/null

echo "Setting subscription context to $SUBSCRIPTION_ID..."
az account set --subscription "$SUBSCRIPTION_ID"

USER_UPN=$(az account show --query user.name -o tsv)
echo "✅ Logged in as user: $USER_UPN"
echo "Using Key Vault: $KV_NAME ($ENV)"

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

  echo "✅ Secret '$SECRET_NAME' successfully created in $KV_NAME ($ENV)."
fi

# ==============================
# ROTATE EXISTING SECRET
# ==============================
if [[ "$ACTION" == "Rotate existing secret" ]]; then
  echo "Fetching existing secrets from Key Vault '$KV_NAME'..."
  SECRET_LIST=$(az keyvault secret list --vault-name "$KV_NAME" --query "[].name" -o tsv)

  if [[ -z "$SECRET_LIST" ]]; then
    echo "⚠️ No secrets found in Key Vault '$KV_NAME'."
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

  echo "✅ Secret '$SECRET_NAME' successfully rotated in $KV_NAME ($ENV)."
fi

# ==============================
# CLEANUP
# ==============================
az logout > /dev/null
echo "✅ Logged out. Done."
