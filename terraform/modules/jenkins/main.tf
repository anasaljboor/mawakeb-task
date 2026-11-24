locals {
  plugins = compact(split("\n", file("${path.module}/plugins.txt")))
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = var.namespaces.jenkins
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version

  timeout         = 900
  wait            = true
  atomic          = false
  cleanup_on_fail = false

  values = [
    templatefile("${path.module}/values.yaml.tftpl", {
      jenkins_image_tag = var.image_tag
      jenkins_hostname  = var.hostname
      git_repo_url      = var.git_repo_url
      git_branch        = var.git_branch
      ns_jenkins        = var.namespaces.jenkins
      ns_agents         = var.namespaces.agents
      ns_argocd         = var.namespaces.argocd
      controller_sa     = kubernetes_service_account_v1.controller.metadata[0].name
      agent_sa          = kubernetes_service_account_v1.agent.metadata[0].name
      home_claim        = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
      admin_secret      = kubernetes_secret_v1.admin.metadata[0].name
      registry_secret   = kubernetes_secret_v1.registry.metadata[0].name
      gitops_secret     = kubernetes_secret_v1.gitops.metadata[0].name
      plugins           = local.plugins
      registry_server   = var.registry_server
      image_repo        = var.image_repo
      app_hostname      = var.app_hostname
      ingress_url       = var.ingress_url
      gitops_repo_url   = var.gitops_repo_url
      gitops_branch     = var.gitops_branch
      gitops_app_path   = var.gitops_app_path
    })
  ]

  depends_on = [
    kubernetes_role_binding_v1.agent_manager,
    kubernetes_role_binding_v1.casc_reload,
  ]
}
