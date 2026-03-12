output "prod_namespace" {
  value = kubernetes_namespace.prod.metadata[0].name
}

output "dev_readonly_service_account" {
  value = kubernetes_service_account_v1.dev_reader.metadata[0].name
}

output "prod_operator_service_account" {
  value = kubernetes_service_account_v1.prod_operator.metadata[0].name
}

output "overprivilege_simulation_enabled" {
  value = var.simulate_overprivilege
}
