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
