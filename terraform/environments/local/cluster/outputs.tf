output "cluster_name" { value = module.kind_cluster.name }
output "context_name" { value = module.kind_cluster.context_name }
output "kubeconfig_path" { value = module.kind_cluster.kubeconfig_path }
output "endpoint" { value = module.kind_cluster.endpoint }
output "ingress_node_ports" {
  value = { http = var.http_node_port, https = var.https_node_port }
}
