variable "namespaces" {
  type = object({
    jenkins = string
    agents  = string
    app     = string
    argocd  = string
  })
}
variable "chart_version" { type = string }
variable "image_tag" { type = string }
variable "hostname" { type = string }
variable "storage_class" { type = string }
variable "home_size" { type = string }
variable "trivy_cache_size" { type = string }
variable "git_repo_url" { type = string }
variable "git_branch" { type = string }
variable "registry_server" { type = string }
variable "registry_username" { type = string }
variable "image_repo" { type = string }
variable "app_hostname" { type = string }
variable "ingress_url" { type = string }
variable "gitops_repo_url" { type = string }
variable "gitops_branch" { type = string }
variable "gitops_app_path" { type = string }
variable "argocd_app_name" { type = string }
variable "secrets_revision" { type = number }
variable "admin_password" {
  type      = string
  sensitive = true
  ephemeral = true
}
variable "registry_token" {
  type      = string
  sensitive = true
  ephemeral = true
}
variable "gitops_token" {
  type      = string
  sensitive = true
  ephemeral = true
}
