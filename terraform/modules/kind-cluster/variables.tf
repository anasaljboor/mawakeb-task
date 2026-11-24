variable "name" { type = string }
variable "node_image" { type = string }
variable "kubeconfig_path" { type = string }
variable "http_host_port" { type = number }
variable "https_host_port" { type = number }
variable "http_node_port" { type = number }
variable "https_node_port" { type = number }
variable "listen_address" { type = string }
variable "worker_pools" {
  type = map(object({
    labels = map(string)
    taints = list(string)
  }))
}
