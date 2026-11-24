resource "kubernetes_service_account_v1" "sync" {
  metadata {
    name      = "argocd-sync"
    namespace = var.namespaces.app
  }
  automount_service_account_token = false
}

resource "kubernetes_role_v1" "sync" {
  metadata {
    name      = "argocd-sync"
    namespace = var.namespaces.app
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

resource "kubernetes_role_binding_v1" "sync" {
  metadata {
    name      = "argocd-sync"
    namespace = var.namespaces.app
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.sync.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.sync.metadata[0].name
    namespace = var.namespaces.app
  }
}
