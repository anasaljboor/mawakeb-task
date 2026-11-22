resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace_v1.this["ingress"].metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_chart_version

  timeout = 300
  wait    = true

  values = [
    templatefile("${path.module}/values/traefik.yaml.tftpl", {
      http_node_port  = var.ingress_http_node_port
      https_node_port = var.ingress_https_node_port
    })
  ]
}
