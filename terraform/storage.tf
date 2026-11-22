resource "kubernetes_persistent_volume_claim_v1" "jenkins_home" {
  metadata {
    name      = "jenkins-home"
    namespace = local.ns_jenkins
    labels = {
      "app.kubernetes.io/part-of" = "beacon-lab"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = var.jenkins_storage_size
      }
    }
  }

  wait_until_bound = false
}
