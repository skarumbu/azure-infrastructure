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
  description = "Azure AD tenant ID. Pass via TF_VAR_ideas_api_auth_tenant_id."
}

variable "ideas_api_write_key" {
  type        = string
  sensitive   = true
  description = "Shared secret for ideator job → ideas-api writes. Pass via TF_VAR_ideas_api_write_key."
}
