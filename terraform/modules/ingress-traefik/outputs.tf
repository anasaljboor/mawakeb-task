output "ingress_class" { value = "traefik" }
output "service_url" { value = "http://traefik.${var.namespace}.svc.cluster.local" }
