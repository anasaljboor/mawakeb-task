
locals {
  pod_security_version = "latest"

  namespaces = {
    jenkins = {
      name  = var.jenkins_namespace
      level = "restricted"
    }
    agents = {
      name  = var.agents_namespace
      level = "privileged"
    }
    app = {
      name  = var.app_namespace
      level = "restricted"
    }
    ingress = {
      name  = var.ingress_namespace
      level = "restricted"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  for_each = local.namespaces

  metadata {
    name = each.value.name
    labels = {
      "app.kubernetes.io/part-of"                  = "beacon-lab"
      "app.kubernetes.io/managed-by"               = "terraform"
      "pod-security.kubernetes.io/enforce"         = each.value.level
      "pod-security.kubernetes.io/enforce-version" = local.pod_security_version
      "pod-security.kubernetes.io/warn"            = "restricted"
      "pod-security.kubernetes.io/audit"           = "restricted"
    }
  }
}
