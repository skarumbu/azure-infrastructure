output "ideas_api_url" {
  value       = module.ideas_api.function_app_url
  description = "Set as REACT_APP_IDEAS_API_BASE_URL in my-website Static Web App env vars"
}

output "ideas_api_app_name" {
  value       = module.ideas_api.function_app_name
  description = "Use as IDEAS_API_APP_NAME in the ideas-api GitHub Actions secrets"
}

output "ideas_api_client_id" {
  value       = azuread_application.ideas_api.client_id
  description = "Update ideasApiRequest scope in my-website/src/authConfig.js with this value"
}
