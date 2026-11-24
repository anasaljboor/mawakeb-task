resource "kind_cluster" "this" {
  name            = var.name
  node_image      = var.node_image
  kubeconfig_path = pathexpand(var.kubeconfig_path)
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role  = "control-plane"
      image = var.node_image

      extra_port_mappings {
        container_port = var.http_node_port
        host_port      = var.http_host_port
        listen_address = var.listen_address
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = var.https_node_port
        host_port      = var.https_host_port
        listen_address = var.listen_address
        protocol       = "TCP"
      }
    }

    dynamic "node" {
      for_each = var.worker_pools
      content {
        role   = "worker"
        image  = var.node_image
        labels = node.value.labels
        kubeadm_config_patches = length(node.value.taints) == 0 ? [] : [
          yamlencode({
            kind = "JoinConfiguration"
            nodeRegistration = {
              taints = [for t in node.value.taints : {
                key    = split("=", split(":", t)[0])[0]
                value  = split("=", split(":", t)[0])[1]
                effect = split(":", t)[1]
              }]
            }
          })
        ]
      }
    }
  }
}
