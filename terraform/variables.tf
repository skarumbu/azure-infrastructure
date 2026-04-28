variable "subscription_id" {
  type        = string
  sensitive   = true
  description = "Azure subscription ID. Pass via TF_VAR_subscription_id."
}

variable "location" {
  type        = string
  description = "Azure region — must match the Bicep deployment region"
  default     = "centralus"
}

variable "ideas_api_auth_tenant_id" {
  type        = string
  description = "Azure AD tenant ID for ideas-api EasyAuth. Pass via TF_VAR_ideas_api_auth_tenant_id."
}

variable "ideas_api_auth_client_id" {
  type        = string
  description = "App Registration client ID for ideas-api."
  default     = "bb744b67-4a31-41ab-a52b-006f90fce6cb"
}

variable "ideas_api_auth_client_secret" {
  type        = string
  sensitive   = true
  description = "App Registration client secret for ideas-api. Pass via TF_VAR_ideas_api_auth_client_secret."
}

variable "ideas_api_write_key" {
  type        = string
  sensitive   = true
  description = "Shared secret for ideator job → ideas-api writes. Pass via TF_VAR_ideas_api_write_key."
}
