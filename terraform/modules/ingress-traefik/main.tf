resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = var.namespace
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.chart_version

  timeout = 300
  wait    = true

  values = [
    templatefile("${path.module}/values.yaml.tftpl", {
      service_type        = var.service_type
      http_node_port      = var.http_node_port
      https_node_port     = var.https_node_port
      ingress_endpoint_ip = var.ingress_endpoint_ip
      service_annotations = var.service_annotations
      node_selector       = var.node_selector
    })
  ]
}
