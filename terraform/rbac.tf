
locals {
  ns_jenkins = kubernetes_namespace_v1.this["jenkins"].metadata[0].name
  ns_agents  = kubernetes_namespace_v1.this["agents"].metadata[0].name
  ns_app     = kubernetes_namespace_v1.this["app"].metadata[0].name
}

resource "kubernetes_service_account_v1" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = local.ns_jenkins
  }
}

resource "kubernetes_service_account_v1" "agent" {
  metadata {
    name      = "jenkins-agent"
    namespace = local.ns_agents
  }
  automount_service_account_token = false
}

resource "kubernetes_service_account_v1" "deployer" {
  metadata {
    name      = "beacon-deployer"
    namespace = local.ns_agents
  }
}


resource "kubernetes_role_v1" "agent_manager" {
  metadata {
    name      = "jenkins-agent-manager"
    namespace = local.ns_agents
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
    resources  = ["pods/log"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "agent_manager" {
  metadata {
    name      = "jenkins-agent-manager"
    namespace = local.ns_agents
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.agent_manager.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.jenkins.metadata[0].name
    namespace = local.ns_jenkins
  }
}


resource "kubernetes_role_v1" "deployer" {
  metadata {
    name      = "beacon-deployer"
    namespace = local.ns_app
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

resource "kubernetes_role_v1" "deployer_argocd" {
  metadata {
    name      = "beacon-app-reader"
    namespace = kubernetes_namespace_v1.this["argocd"].metadata[0].name
  }

  rule {
    api_groups     = ["argoproj.io"]
    resources      = ["applications"]
    resource_names = ["beacon"]
    verbs          = ["get", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "deployer_argocd" {
  metadata {
    name      = "beacon-app-reader"
    namespace = kubernetes_namespace_v1.this["argocd"].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deployer_argocd.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.deployer.metadata[0].name
    namespace = local.ns_agents
  }
}

resource "kubernetes_role_binding_v1" "deployer" {
  metadata {
    name      = "beacon-deployer"
    namespace = local.ns_app
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deployer.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.deployer.metadata[0].name
    namespace = local.ns_agents
  }
}

resource "kubernetes_role_v1" "casc_reload" {
  metadata {
    name      = "jenkins-casc-reload"
    namespace = local.ns_jenkins
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
    namespace = local.ns_jenkins
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.casc_reload.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.jenkins.metadata[0].name
    namespace = local.ns_jenkins
  }
}

resource "kubernetes_service_account_v1" "argocd_sync" {
  metadata {
    name      = "argocd-sync"
    namespace = local.ns_app
  }
  automount_service_account_token = false
}

resource "kubernetes_role_v1" "argocd_sync" {
  metadata {
    name      = "argocd-sync"
    namespace = local.ns_app
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["services", "configmaps"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "argocd_sync" {
  metadata {
    name      = "argocd-sync"
    namespace = local.ns_app
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.argocd_sync.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argocd_sync.metadata[0].name
    namespace = local.ns_app
  }
}
