variable "namespaces" {
  type = object({
    monitoring = string
    app        = string
    ingress    = string
  })
}
variable "log_namespaces" { type = list(string) }
variable "kube_prometheus_stack_chart_version" { type = string }
variable "loki_chart_version" { type = string }
variable "alloy_chart_version" { type = string }
variable "storage_class" { type = string }
variable "prometheus_retention" { type = string }
variable "grafana_hostname" { type = string }
variable "secrets_revision" { type = number }
variable "grafana_admin_password" {
  type      = string
  sensitive = true
  ephemeral = true
}
