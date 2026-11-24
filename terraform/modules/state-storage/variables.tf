variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "storage_account_name" { type = string }
variable "container_name" { type = string }
variable "allowed_ip_ranges" { type = list(string) }
variable "state_writer_principal_ids" { type = list(string) }
variable "retention_days" { type = number }
variable "tags" { type = map(string) }
