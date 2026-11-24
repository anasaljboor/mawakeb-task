resource "kubernetes_secret_v1" "admin" {
  metadata {
    name      = "jenkins-admin"
    namespace = var.namespaces.jenkins
  }
  data_wo = {
    "jenkins-admin-user"     = "admin"
    "jenkins-admin-password" = var.admin_password
  }
  data_wo_revision = var.secrets_revision
}

resource "kubernetes_secret_v1" "registry" {
  metadata {
    name      = "registry"
    namespace = var.namespaces.jenkins
  }
  data_wo = {
    username = var.registry_username
    token    = var.registry_token
  }
  data_wo_revision = var.secrets_revision
}

resource "kubernetes_secret_v1" "gitops" {
  metadata {
    name      = "gitops"
    namespace = var.namespaces.jenkins
  }
  data_wo = {
    username = "git"
    token    = var.gitops_token
  }
  data_wo_revision = var.secrets_revision
}
