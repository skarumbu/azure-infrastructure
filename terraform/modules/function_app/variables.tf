variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "app_name" {
  type        = string
  description = "Full resource name for the Function App (must be globally unique, e.g. ideas-api-prod)"
}

variable "python_version" {
  type    = string
  default = "3.11"
}

variable "app_settings" {
  type        = map(string)
  description = "Non-sensitive app settings / environment variables"
  default     = {}
}

variable "secret_app_settings" {
  type        = map(string)
  sensitive   = true
  description = "Sensitive app settings merged alongside non-sensitive ones"
  default     = {}
}

variable "auth_tenant_id" {
  type        = string
  description = "Azure AD tenant ID for EasyAuth"
}

variable "auth_client_id" {
  type        = string
  description = "App Registration client ID for EasyAuth"
}

variable "auth_client_secret" {
  type        = string
  sensitive   = true
  description = "App Registration client secret for EasyAuth"
}

variable "tags" {
  type    = map(string)
  default = {}
}
