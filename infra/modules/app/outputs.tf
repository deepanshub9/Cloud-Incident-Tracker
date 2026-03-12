output "image_uri" {
  value = local.image_uri
}

output "namespace" {
  value = kubernetes_namespace.this.metadata[0].name
}

output "deployment_name" {
  value = kubernetes_deployment_v1.this.metadata[0].name
}

output "service_name" {
  value = kubernetes_service_v1.this.metadata[0].name
}

output "service_lb_hostname" {
  value = try(kubernetes_service_v1.this.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "hpa_name" {
  value = kubernetes_horizontal_pod_autoscaler_v2.this.metadata[0].name
}
