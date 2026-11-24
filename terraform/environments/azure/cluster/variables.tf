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
variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "beacon-prod"
}
variable "acr_name" {
  description = "Globally unique ACR name (5-50 lowercase letters and digits)."
  type        = string
  default     = ""
}
variable "key_vault_name" {
  description = "Globally unique Key Vault name (3-24 characters)."
  type        = string
  default     = ""
}
variable "kubernetes_version" {
  description = "AKS Kubernetes minor version; patches follow the automatic upgrade channel."
  type        = string
  default     = "1.36"
}
variable "aks_sku_tier" {
  description = "AKS control plane tier (Free for a lab, Standard for an uptime SLA)."
  type        = string
  default     = "Standard"
}
variable "admin_group_object_ids" {
  description = "Entra ID groups granted AKS cluster-admin through Azure RBAC. Local accounts are disabled."
  type        = list(string)
  default     = []
}
variable "operator_principal_ids" {
  description = "Principals allowed to set Key Vault secrets (Key Vault Secrets Officer)."
  type        = list(string)
  default     = []
}
variable "platform_reader_principal_ids" {
  description = "Principals that run the platform stack and read Key Vault secrets ephemerally (Key Vault Secrets User)."
  type        = list(string)
  default     = []
}
variable "admin_ip_ranges" {
  description = "CIDRs allowed to reach the AKS API server and Key Vault."
  type        = list(string)
  default     = []
}
variable "ingress_source_ranges" {
  description = "CIDRs allowed to reach the ingress load balancer on 80/443."
  type        = list(string)
  default     = ["Internet"]
}
variable "vnet_cidr" {
  description = "Virtual network address space."
  type        = string
  default     = "10.50.0.0/16"
}
variable "system_vm_size" {
  description = "VM size of the system (critical add-ons only) node pool."
  type        = string
  default     = "Standard_D2s_v5"
}
variable "apps_vm_size" {
  description = "VM size of the apps node pool."
  type        = string
  default     = "Standard_D4s_v5"
}
variable "builds_vm_size" {
  description = "VM size of the tainted builds node pool (scales to zero when idle)."
  type        = string
  default     = "Standard_D4s_v5"
}
variable "zones" {
  description = "Availability zones for node pools."
  type        = list(string)
  default     = ["1", "2", "3"]
}
variable "create_log_analytics" {
  description = "Create a Log Analytics workspace and enable Container Insights (adds ingestion cost)."
  type        = bool
  default     = false
}
variable "budget_monthly_amount" {
  description = "Monthly cost budget for the resource group, in the billing currency."
  type        = number
  default     = 400
}
variable "budget_start_date" {
  description = "First day of the budget period (YYYY-MM-01T00:00:00Z), not in the past."
  type        = string
  default     = "2026-12-01T00:00:00Z"
}
variable "budget_contact_emails" {
  description = "Recipients of budget alerts."
  type        = list(string)
  default     = []
}
variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project    = "beacon"
    managed-by = "terraform"
  }
}
