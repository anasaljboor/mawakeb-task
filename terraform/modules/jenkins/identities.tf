resource "kubernetes_service_account_v1" "controller" {
  metadata {
    name      = "jenkins"
    namespace = var.namespaces.jenkins
  }
}

resource "kubernetes_service_account_v1" "agent" {
  metadata {
    name      = "jenkins-agent"
    namespace = var.namespaces.agents
  }
  automount_service_account_token = false
}

resource "kubernetes_service_account_v1" "deployer" {
  metadata {
    name      = "beacon-deployer"
    namespace = var.namespaces.agents
  }
}

resource "kubernetes_role_v1" "agent_manager" {
  metadata {
    name      = "jenkins-agent-manager"
    namespace = var.namespaces.agents
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create", "get"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/log", "events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "agent_manager" {
  metadata {
    name      = "jenkins-agent-manager"
    namespace = var.namespaces.agents
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.agent_manager.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.controller.metadata[0].name
    namespace = var.namespaces.jenkins
  }
}

resource "kubernetes_role_v1" "casc_reload" {
  metadata {
    name      = "jenkins-casc-reload"
    namespace = var.namespaces.jenkins
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "casc_reload" {
  metadata {
    name      = "jenkins-casc-reload"
    namespace = var.namespaces.jenkins
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.casc_reload.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.controller.metadata[0].name
    namespace = var.namespaces.jenkins
  }
}

resource "kubernetes_role_v1" "deployer_app_reader" {
  metadata {
    name      = "beacon-deployer"
    namespace = var.namespaces.app
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "events", "services", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "deployer_app_reader" {
  metadata {
    name      = "beacon-deployer"
    namespace = var.namespaces.app
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deployer_app_reader.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.deployer.metadata[0].name
    namespace = var.namespaces.agents
  }
}

resource "kubernetes_role_v1" "deployer_application_reader" {
  metadata {
    name      = "beacon-app-reader"
    namespace = var.namespaces.argocd
  }
  rule {
    api_groups     = ["argoproj.io"]
    resources      = ["applications"]
    resource_names = [var.argocd_app_name]
    verbs          = ["get", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "deployer_application_reader" {
  metadata {
    name      = "beacon-app-reader"
    namespace = var.namespaces.argocd
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deployer_application_reader.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.deployer.metadata[0].name
    namespace = var.namespaces.agents
  }
}
