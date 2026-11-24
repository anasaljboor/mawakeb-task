variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "kubernetes_version" { type = string }
variable "sku_tier" { type = string }
variable "subnet_id" { type = string }
variable "tenant_id" { type = string }
variable "admin_group_object_ids" { type = list(string) }
variable "api_authorized_ip_ranges" { type = list(string) }
variable "system_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
    zones     = list(string)
  })
}
variable "user_pools" {
  type = map(object({
    vm_size   = string
    min_count = number
    max_count = number
    zones     = list(string)
    labels    = map(string)
    taints    = list(string)
  }))
}
variable "pod_cidr" { type = string }
variable "service_cidr" { type = string }
variable "dns_service_ip" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "tags" { type = map(string) }
