variable "git_repo_url" {
  description = "Application repository the Jenkins job builds."
  type        = string
}
variable "git_branch" {
  description = "Branch the Jenkins job builds."
  type        = string
  default     = "main"
}
variable "registry_server" {
  description = "Container registry the pipeline pushes to."
  type        = string
  default     = "docker.io"
}
variable "registry_username" {
  description = "Registry account (not secret); the image repository is <server>/<username>/beacon."
  type        = string
}
variable "gitops_repo_url" {
  description = "GitOps repository ArgoCD reconciles and Jenkins commits digests to."
  type        = string
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
variable "base_domain" {
  description = "Wildcard DNS suffix for lab hostnames (nip.io resolves to the embedded IP)."
  type        = string
  default     = "127.0.0.1.nip.io"
}
variable "storage_class" {
  description = "StorageClass for persistent volumes (Kind ships local-path as standard)."
  type        = string
  default     = "standard"
}
variable "pod_security_version" {
  description = "Pod Security Admission policy version enforced in every namespace."
  type        = string
  default     = "latest"
}
variable "ingress_http_node_port" {
  description = "Must equal http_node_port in the cluster stack."
  type        = number
  default     = 30080
}
variable "ingress_https_node_port" {
  description = "Must equal https_node_port in the cluster stack."
  type        = number
  default     = 30443
}
variable "chart_versions" {
  description = "Pinned Helm chart versions."
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
  description = "Pinned Jenkins controller image tag; regenerate modules/jenkins/plugins.txt when changing it."
  type        = string
  default     = "2.580.2-jdk25"
}
variable "prometheus_retention" {
  description = "How long Prometheus keeps samples."
  type        = string
  default     = "2d"
}
variable "secrets_revision" {
  description = "Increase to re-write every write-only secret value (rotation)."
  type        = number
  default     = 1
}
variable "registry_token" {
  description = "Registry push token. Supply via TF_VAR_registry_token."
  type        = string
  sensitive   = true
  ephemeral   = true
}
variable "github_token" {
  description = "Fine-grained GitHub token, Contents read/write on the GitOps repository only. Supply via TF_VAR_github_token."
  type        = string
  sensitive   = true
  ephemeral   = true
}
variable "jenkins_admin_password" {
  description = "Jenkins admin password. Supply via TF_VAR_jenkins_admin_password."
  type        = string
  sensitive   = true
  ephemeral   = true
}
variable "grafana_admin_password" {
  description = "Grafana admin password. Supply via TF_VAR_grafana_admin_password."
  type        = string
  sensitive   = true
  ephemeral   = true
}
