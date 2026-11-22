
locals {
  ns_jenkins = kubernetes_namespace_v1.this["jenkins"].metadata[0].name
  ns_agents  = kubernetes_namespace_v1.this["agents"].metadata[0].name
  ns_app     = kubernetes_namespace_v1.this["app"].metadata[0].name
}

# ---------------------------------------------------------------- service accounts

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
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"] # rollout status / rollout undo read revision history
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["services", "configmaps"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "events"] # diagnostics when a rollout fails
    verbs      = ["get", "list", "watch"]
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
