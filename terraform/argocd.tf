resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.this["argocd"].metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/values/argocd.yaml.tftpl", {
      hostname = var.argocd_hostname
    })
  ]

  depends_on = [helm_release.traefik]
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  namespace  = kubernetes_namespace_v1.this["argocd"].metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [
    templatefile("${path.module}/values/argocd-apps.yaml.tftpl", {
      ns_argocd       = kubernetes_namespace_v1.this["argocd"].metadata[0].name
      ns_app          = local.ns_app
      sync_sa         = kubernetes_service_account_v1.argocd_sync.metadata[0].name
      gitops_repo_url = var.gitops_repo_url
      gitops_branch   = var.gitops_branch
      gitops_app_path = var.gitops_app_path
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_role_binding_v1.argocd_sync,
  ]
}
