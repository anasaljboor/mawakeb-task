variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context of the target cluster (created by scripts/cluster-up.sh)"
  type        = string
  default     = "kind-beacon"
}

variable "jenkins_namespace" {
  description = "Namespace for the Jenkins controller"
  type        = string
  default     = "jenkins"
}

variable "agents_namespace" {
  description = "Namespace for ephemeral Jenkins build agents"
  type        = string
  default     = "jenkins-agents"
}

variable "app_namespace" {
  description = "Namespace the application is deployed to"
  type        = string
  default     = "beacon"
}

variable "git_repo_url" {
  description = "Repository the pipeline job builds"
  type        = string
}

variable "dockerhub_username" {
  description = "Docker Hub account (not secret). The token is injected separately."
  type        = string
}

variable "jenkins_hostname" {
  description = "Hostname Jenkins is served on through the ingress controller"
  type        = string
  default     = "jenkins.127.0.0.1.nip.io"
}

variable "git_branch" {
  description = "Branch the pipeline job builds"
  type        = string
  default     = "main"
}

variable "storage_class" {
  description = "StorageClass for Jenkins home"
  type        = string
  default     = "standard"
}

variable "jenkins_storage_size" {
  description = "Size of the Jenkins home volume"
  type        = string
  default     = "8Gi"
}

variable "jenkins_chart_version" {
  description = "Pinned version of the jenkins Helm chart"
  type        = string
  default     = "5.13.3"
}

variable "jenkins_image_tag" {
  description = "Pinned Jenkins controller image tag (LTS)"
  type        = string
  default     = "2.580.2-jdk25"
}

variable "ingress_namespace" {
  description = "Namespace for the ingress controller"
  type        = string
  default     = "traefik"
}

variable "traefik_chart_version" {
  description = "Pinned version of the traefik Helm chart"
  type        = string
  default     = "42.4.1"
}

variable "ingress_http_node_port" {
  description = "NodePort for HTTP; must match the containerPort mapped to localhost:80 in cluster/kind-config.yaml"
  type        = number
  default     = 30080
}

variable "ingress_https_node_port" {
  description = "NodePort for HTTPS; must match the containerPort mapped to localhost:443 in cluster/kind-config.yaml"
  type        = number
  default     = 30443
}

variable "app_hostname" {
  description = "Hostname the application is served on through the ingress controller"
  type        = string
  default     = "beacon.127.0.0.1.nip.io"
}

variable "argocd_namespace" {
  description = "Namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Pinned version of the argo-cd Helm chart"
  type        = string
  default     = "10.18.2"
}

variable "argocd_apps_chart_version" {
  description = "Pinned version of the argocd-apps Helm chart (Applications and AppProjects)"
  type        = string
  default     = "2.0.8"
}

variable "argocd_hostname" {
  description = "Hostname the ArgoCD UI is served on through the ingress controller"
  type        = string
  default     = "argocd.127.0.0.1.nip.io"
}

variable "gitops_repo_url" {
  description = "GitOps repository ArgoCD reconciles and Jenkins commits image digests to"
  type        = string
}

variable "gitops_branch" {
  description = "Branch of the GitOps repository ArgoCD tracks"
  type        = string
  default     = "main"
}

variable "gitops_app_path" {
  description = "Path of the beacon application inside the GitOps repository"
  type        = string
  default     = "apps/beacon"
}
