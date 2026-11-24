variable "cluster_name" {
  description = "Kind cluster name; the kubeconfig context becomes kind-<name>."
  type        = string
  default     = "beacon"
}
variable "node_image" {
  description = "Kind node image pinned by digest."
  type        = string
  default     = "kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
}
variable "kubeconfig_path" {
  description = "Kubeconfig the cluster context is merged into."
  type        = string
  default     = "~/.kube/config"
}
variable "listen_address" {
  description = "Host address the ingress ports bind to; 127.0.0.1 keeps them off the LAN."
  type        = string
  default     = "127.0.0.1"
}
variable "http_host_port" {
  description = "Host port mapped to the ingress controller's HTTP NodePort."
  type        = number
  default     = 80
}
variable "https_host_port" {
  description = "Host port mapped to the ingress controller's HTTPS NodePort."
  type        = number
  default     = 443
}
variable "http_node_port" {
  description = "Ingress HTTP NodePort; must equal ingress_http_node_port in the platform stack."
  type        = number
  default     = 30080
}
variable "https_node_port" {
  description = "Ingress HTTPS NodePort; must equal ingress_https_node_port in the platform stack."
  type        = number
  default     = 30443
}
