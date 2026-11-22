locals {
  jenkins_plugins = compact(split("\n", file("${path.module}/jenkins-plugins.txt")))
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = local.ns_jenkins
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.jenkins_chart_version

  timeout         = 900
  wait            = true
  atomic          = false
  cleanup_on_fail = false

  values = [
    templatefile("${path.module}/values/jenkins.yaml.tftpl", {
      jenkins_image_tag = var.jenkins_image_tag
      jenkins_hostname  = var.jenkins_hostname
      git_repo_url      = var.git_repo_url
      git_branch        = var.git_branch
      ns_agents         = local.ns_agents
      ns_jenkins        = local.ns_jenkins
      controller_sa     = kubernetes_service_account_v1.jenkins.metadata[0].name
      agent_sa          = kubernetes_service_account_v1.agent.metadata[0].name
      home_claim        = kubernetes_persistent_volume_claim_v1.jenkins_home.metadata[0].name
      admin_secret      = kubernetes_secret_v1.jenkins_admin.metadata[0].name
      dockerhub_secret  = kubernetes_secret_v1.dockerhub.metadata[0].name
      plugins           = local.jenkins_plugins
    })
  ]

  depends_on = [
    kubernetes_role_binding_v1.agent_manager,
    kubernetes_role_binding_v1.casc_reload,
  ]
}
