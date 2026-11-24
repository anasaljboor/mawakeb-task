resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespaces.argocd
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/argocd.yaml.tftpl", {
      hostname = var.hostname
    })
  ]
}

resource "helm_release" "apps" {
  name       = "argocd-apps"
  namespace  = var.namespaces.argocd
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version

  values = [
    templatefile("${path.module}/argocd-apps.yaml.tftpl", {
      ns_argocd       = var.namespaces.argocd
      ns_app          = var.namespaces.app
      sync_sa         = kubernetes_service_account_v1.sync.metadata[0].name
      gitops_repo_url = var.gitops_repo_url
      gitops_branch   = var.gitops_branch
      gitops_app_path = var.gitops_app_path
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_role_binding_v1.sync,
  ]
}
