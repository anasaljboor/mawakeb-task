variable "namespace" { type = string }
variable "chart_version" { type = string }
variable "service_type" { type = string }
variable "http_node_port" { type = number }
variable "https_node_port" { type = number }
variable "ingress_endpoint_ip" { type = string }
variable "service_annotations" { type = map(string) }
variable "node_selector" { type = map(string) }
