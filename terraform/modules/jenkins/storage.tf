resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "jenkins-home"
    namespace = var.namespaces.jenkins
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = { storage = var.home_size }
    }
  }
  wait_until_bound = false
}

resource "kubernetes_persistent_volume_claim_v1" "trivy_cache" {
  metadata {
    name      = "trivy-cache"
    namespace = var.namespaces.agents
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = { storage = var.trivy_cache_size }
    }
  }
  wait_until_bound = false
}
