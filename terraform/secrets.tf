variable "dockerhub_token" {
  description = "Docker Hub access token (Read & Write). Supply via TF_VAR_dockerhub_token."
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

variable "secrets_revision" {
  description = "Increase to re-write the secret values (rotation)."
  type        = number
  default     = 1
}

resource "kubernetes_secret_v1" "jenkins_admin" {
  metadata {
    name      = "jenkins-admin"
    namespace = local.ns_jenkins
  }

  data_wo = {
    "jenkins-admin-user"     = "admin"
    "jenkins-admin-password" = var.jenkins_admin_password
  }
  data_wo_revision = var.secrets_revision
}

resource "kubernetes_secret_v1" "dockerhub" {
  metadata {
    name      = "dockerhub"
    namespace = local.ns_jenkins
  }

  data_wo = {
    username = var.dockerhub_username
    token    = var.dockerhub_token
  }
  data_wo_revision = var.secrets_revision
}
