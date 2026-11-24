output "names" { value = { for k, ns in kubernetes_namespace_v1.this : k => ns.metadata[0].name } }
