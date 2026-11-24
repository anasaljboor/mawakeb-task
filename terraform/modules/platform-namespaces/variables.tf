variable "namespaces" {
  type = map(object({
    name  = string
    level = string
  }))
}
variable "pod_security_version" { type = string }
variable "labels" { type = map(string) }
