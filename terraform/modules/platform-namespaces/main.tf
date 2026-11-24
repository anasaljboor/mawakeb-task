resource "kubernetes_namespace_v1" "this" {
  for_each = var.namespaces

  metadata {
    name = each.value.name
    labels = merge(var.labels, {
      "pod-security.kubernetes.io/enforce"         = each.value.level
      "pod-security.kubernetes.io/enforce-version" = var.pod_security_version
      "pod-security.kubernetes.io/warn"            = "restricted"
      "pod-security.kubernetes.io/audit"           = "restricted"
    })
  }
}
