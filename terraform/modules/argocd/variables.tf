variable "namespaces" {
  type = object({
    argocd = string
    app    = string
  })
}
variable "chart_version" { type = string }
variable "apps_chart_version" { type = string }
variable "hostname" { type = string }
variable "app_name" { type = string }
variable "gitops_repo_url" { type = string }
variable "gitops_branch" { type = string }
variable "gitops_app_path" { type = string }
