resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = var.namespaces.monitoring
  }
  data_wo = {
    "admin-user"     = "admin"
    "admin-password" = var.grafana_admin_password
  }
  data_wo_revision = var.secrets_revision
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = var.namespaces.monitoring
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version

  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/loki.yaml.tftpl", {
      storage_class = var.storage_class
    })
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kps"
  namespace  = var.namespaces.monitoring
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version

  timeout = 900
  wait    = true

  values = [
    templatefile("${path.module}/kube-prometheus-stack.yaml.tftpl", {
      retention        = var.prometheus_retention
      storage_class    = var.storage_class
      ns_app           = var.namespaces.app
      ns_ingress       = var.namespaces.ingress
      ns_monitoring    = var.namespaces.monitoring
      grafana_secret   = kubernetes_secret_v1.grafana_admin.metadata[0].name
      grafana_hostname = var.grafana_hostname
    })
  ]

  depends_on = [helm_release.loki]
}

resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = var.namespaces.monitoring
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version

  timeout = 300
  wait    = true

  values = [
    templatefile("${path.module}/alloy.yaml.tftpl", {
      ns_monitoring  = var.namespaces.monitoring
      log_namespaces = join(", ", [for n in var.log_namespaces : "\"${n}\""])
    })
  ]

  depends_on = [helm_release.loki]
}

resource "kubernetes_config_map_v1" "beacon_dashboard" {
  metadata {
    name      = "grafana-dashboard-beacon"
    namespace = var.namespaces.monitoring
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "beacon.json" = file("${path.module}/dashboards/beacon.json")
  }
}
