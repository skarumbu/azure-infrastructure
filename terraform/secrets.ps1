# Set these before running terraform plan/apply.
# Do NOT commit this file with real values.

$env:TF_VAR_subscription_id          = "<fill-in>"
$env:TF_VAR_ideas_api_auth_tenant_id = "<fill-in>"
$env:TF_VAR_ideas_api_write_key      = "<fill-in>"  # also set as IDEAS_WRITE_KEY in discord-bot-infra secrets.ps1
