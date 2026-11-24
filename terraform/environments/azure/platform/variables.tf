variable "deploy_platform" {
  description = "Explicit gate. Nothing is installed until this is true and the cluster stack is applied."
  type        = bool
  default     = false
}
variable "subscription_id" {
  description = "Azure subscription ID (same as the cluster stack)."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}
variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}
variable "resource_group_name" {
  description = "Output resource_group_name of the cluster stack."
  type        = string
  default     = ""
}
variable "aks_name" {
  description = "Output aks_name of the cluster stack."
  type        = string
  default     = ""
}
variable "key_vault_name" {
  description = "Output key_vault_name of the cluster stack."
  type        = string
  default     = ""
}
variable "acr_login_server" {
  description = "Output acr_login_server of the cluster stack."
  type        = string
  default     = ""
}
variable "acr_ci_push_token" {
  description = "Output acr_ci_push_token of the cluster stack (the token name is the registry username)."
  type        = string
  default     = "ci-push"
}
variable "ingress_public_ip" {
  description = "Output ingress_public_ip of the cluster stack."
  type        = string
  default     = ""
}
variable "ingress_public_ip_name" {
  description = "Output ingress_public_ip_name of the cluster stack."
  type        = string
  default     = ""
}
variable "base_domain" {
  description = "DNS suffix for hostnames; empty means <ingress_public_ip>.nip.io."
  type        = string
  default     = ""
}
variable "git_repo_url" {
  description = "Application repository the Jenkins job builds."
  type        = string
  default     = ""
}
variable "git_branch" {
  description = "Branch the Jenkins job builds."
  type        = string
  default     = "main"
}
variable "gitops_repo_url" {
  description = "GitOps repository ArgoCD reconciles."
  type        = string
  default     = ""
}
variable "gitops_branch" {
  description = "Branch of the GitOps repository ArgoCD tracks."
  type        = string
  default     = "main"
}
variable "gitops_app_path" {
  description = "Path of the application inside the GitOps repository."
  type        = string
  default     = "apps/beacon"
}
variable "storage_class" {
  description = "AKS StorageClass for persistent volumes."
  type        = string
  default     = "managed-csi"
}
variable "pod_security_version" {
  description = "Pod Security Admission policy version enforced in every namespace."
  type        = string
  default     = "latest"
}
variable "chart_versions" {
  description = "Pinned Helm chart versions (identical to the local environment)."
  type = object({
    traefik               = string
    jenkins               = string
    argocd                = string
    argocd_apps           = string
    kube_prometheus_stack = string
    loki                  = string
    alloy                 = string
  })
  default = {
    traefik               = "42.4.1"
    jenkins               = "5.13.3"
    argocd                = "10.18.2"
    argocd_apps           = "2.0.8"
    kube_prometheus_stack = "93.9.0"
    loki                  = "7.7.0"
    alloy                 = "1.16.0"
  }
}
variable "jenkins_image_tag" {
  description = "Pinned Jenkins controller image tag."
  type        = string
  default     = "2.580.2-jdk25"
}
variable "prometheus_retention" {
  description = "How long Prometheus keeps samples."
  type        = string
  default     = "7d"
}
variable "secrets_revision" {
  description = "Increase after rotating a Key Vault secret to re-write the Kubernetes Secrets."
  type        = number
  default     = 1
}
variable "key_vault_secret_names" {
  description = "Key Vault secret names holding the platform credentials (set by an operator, never by Terraform)."
  type = object({
    registry_token         = string
    github_token           = string
    jenkins_admin_password = string
    grafana_admin_password = string
  })
  default = {
    registry_token         = "registry-token"
    github_token           = "github-token"
    jenkins_admin_password = "jenkins-admin-password"
    grafana_admin_password = "grafana-admin-password"
  }
}
