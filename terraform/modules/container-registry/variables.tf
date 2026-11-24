variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "sku" { type = string }
variable "pull_principal_ids" { type = list(string) }
variable "push_repositories" { type = list(string) }
variable "tags" { type = map(string) }
