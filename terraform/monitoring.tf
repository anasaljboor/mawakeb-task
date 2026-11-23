locals {
  ns_monitoring  = kubernetes_namespace_v1.this["monitoring"].metadata[0].name
  log_namespaces = [local.ns_app, local.ns_jenkins, local.ns_agents, kubernetes_namespace_v1.this["argocd"].metadata[0].name, kubernetes_namespace_v1.this["ingress"].metadata[0].name]
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = local.ns_monitoring
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/values/loki.yaml.tftpl", {
      storage_class = var.storage_class
    })
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kps"
  namespace  = local.ns_monitoring
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version

  timeout = 900
  wait    = true

  values = [
    templatefile("${path.module}/values/kube-prometheus-stack.yaml.tftpl", {
      retention        = var.prometheus_retention
      storage_class    = var.storage_class
      ns_app           = local.ns_app
      ns_ingress       = kubernetes_namespace_v1.this["ingress"].metadata[0].name
      ns_monitoring    = local.ns_monitoring
      grafana_secret   = kubernetes_secret_v1.grafana_admin.metadata[0].name
      grafana_hostname = var.grafana_hostname
    })
  ]

  depends_on = [helm_release.loki, helm_release.traefik]
}

resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = local.ns_monitoring
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version

  timeout = 300
  wait    = true

  values = [
    templatefile("${path.module}/values/alloy.yaml.tftpl", {
      ns_monitoring  = local.ns_monitoring
      log_namespaces = join(", ", [for n in local.log_namespaces : "\"${n}\""])
    })
  ]

  depends_on = [helm_release.loki]
}

resource "kubernetes_config_map_v1" "beacon_dashboard" {
  metadata {
    name      = "grafana-dashboard-beacon"
    namespace = local.ns_monitoring
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "beacon.json" = file("${path.module}/dashboards/beacon.json")
  }
}
