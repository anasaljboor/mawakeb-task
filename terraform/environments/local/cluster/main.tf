locals {
  worker_pools = {
    apps = {
      labels = { workload = "apps" }
      taints = []
    }
    builds = {
      labels = { workload = "builds" }
      taints = ["dedicated=builds:NoSchedule"]
    }
  }
}

module "kind_cluster" {
  source          = "../../../modules/kind-cluster"
  providers       = { kind = kind }
  name            = var.cluster_name
  node_image      = var.node_image
  kubeconfig_path = var.kubeconfig_path
  listen_address  = var.listen_address
  http_host_port  = var.http_host_port
  https_host_port = var.https_host_port
  http_node_port  = var.http_node_port
  https_node_port = var.https_node_port
  worker_pools    = local.worker_pools
}
