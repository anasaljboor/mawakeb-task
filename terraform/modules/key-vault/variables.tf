variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "allowed_ip_ranges" { type = list(string) }
variable "secret_officer_principal_ids" { type = list(string) }
variable "secret_reader_principal_ids" { type = list(string) }
variable "tags" { type = map(string) }
