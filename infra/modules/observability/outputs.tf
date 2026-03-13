output "monitoring_namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_service_name" {
  value = data.kubernetes_service_v1.grafana.metadata[0].name
}

output "grafana_lb_hostname" {
  value = try(data.kubernetes_service_v1.grafana.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "prometheus_service_name" {
  value = kubernetes_service_v1.prometheus_external.metadata[0].name
}

output "prometheus_lb_hostname" {
  value = try(data.kubernetes_service_v1.prometheus_external.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "alert_rules_name" {
  value = "${var.app_name}-alerts"
}

output "service_monitor_name" {
  value = "${var.app_name}-servicemonitor"
}
