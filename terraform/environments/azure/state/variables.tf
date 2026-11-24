variable "deploy_azure" {
  description = "Explicit cost gate. Nothing is created in Azure until this is true."
  type        = bool
  default     = false
}
variable "subscription_id" {
  description = "Target Azure subscription ID."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}
variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}
variable "location" {
  description = "Azure region."
  type        = string
  default     = "uaenorth"
}
variable "resource_group_name" {
  description = "Resource group dedicated to Terraform state; protected with prevent_destroy."
  type        = string
  default     = "beacon-tfstate"
}
variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 lowercase letters and digits)."
  type        = string
  default     = ""
}
variable "admin_ip_ranges" {
  description = "CIDRs allowed to reach the state storage account."
  type        = list(string)
  default     = []
}
variable "state_writer_principal_ids" {
  description = "Principals that run Terraform (Storage Blob Data Contributor)."
  type        = list(string)
  default     = []
}
variable "retention_days" {
  description = "Soft-delete retention for state blobs and containers."
  type        = number
  default     = 30
}
variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project    = "beacon"
    managed-by = "terraform"
    purpose    = "terraform-state"
  }
}
