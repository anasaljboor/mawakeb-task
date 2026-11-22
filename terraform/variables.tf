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
