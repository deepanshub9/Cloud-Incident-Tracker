resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "67.9.0"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  timeout          = 900
  wait             = true

  set {
    name  = "grafana.service.type"
    value = var.grafana_service_type
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.sidecar.dashboards.enabled"
    value = "true"
  }

  set {
    name  = "grafana.sidecar.dashboards.label"
    value = "grafana_dashboard"
  }

  set {
    name  = "grafana.sidecar.dashboards.searchNamespace"
    value = "ALL"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues"
    value = "false"
  }

  lifecycle {
    ignore_changes = all
  }
}

locals {
  grafana_dashboard = {
    title         = "Incident Tracker Overview"
    uid           = "incident-tracker-overview"
    schemaVersion = 39
    version       = 1
    refresh       = "15s"
    time = {
      from = "now-6h"
      to   = "now"
    }
    panels = [
      {
        id      = 1
        type    = "timeseries"
        title   = "CPU Usage (cores)"
        gridPos = { h = 8, w = 12, x = 0, y = 0 }
        targets = [
          {
            refId = "A"
            expr  = "sum(rate(container_cpu_usage_seconds_total{namespace=\"${var.app_namespace}\",pod=~\"${var.app_name}.*\",container!=\"\",container!=\"POD\"}[5m]))"
          }
        ]
      },
      {
        id      = 2
        type    = "stat"
        title   = "Running Pods"
        gridPos = { h = 8, w = 6, x = 12, y = 0 }
        targets = [
          {
            refId = "A"
            expr  = "count(kube_pod_status_phase{namespace=\"${var.app_namespace}\",pod=~\"${var.app_name}.*\",phase=\"Running\"})"
          }
        ]
      },
      {
        id      = 3
        type    = "timeseries"
        title   = "Pod Restarts (1h)"
        gridPos = { h = 8, w = 6, x = 18, y = 0 }
        targets = [
          {
            refId = "A"
            expr  = "increase(kube_pod_container_status_restarts_total{namespace=\"${var.app_namespace}\",pod=~\"${var.app_name}.*\"}[1h])"
          }
        ]
      },
      {
        id      = 4
        type    = "timeseries"
        title   = "Open Incidents by Severity"
        gridPos = { h = 8, w = 12, x = 0, y = 8 }
        targets = [
          {
            refId        = "A"
            expr         = "incident_open_by_severity"
            legendFormat = "{{severity}}"
          }
        ]
      },
      {
        id      = 5
        type    = "stat"
        title   = "Open Incidents"
        gridPos = { h = 8, w = 6, x = 12, y = 8 }
        targets = [
          {
            refId = "A"
            expr  = "incident_open_total"
          }
        ]
      },
      {
        id      = 6
        type    = "stat"
        title   = "Resolved Incidents"
        gridPos = { h = 8, w = 6, x = 18, y = 8 }
        targets = [
          {
            refId = "A"
            expr  = "incident_resolved_total"
          }
        ]
      }
    ]
  }

  service_monitor_manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "${var.app_name}-servicemonitor"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        app = var.app_name
      }
    }
    spec = {
      namespaceSelector = {
        matchNames = [var.app_namespace]
      }
      selector = {
        matchLabels = {
          app = var.app_name
        }
      }
      endpoints = [
        {
          port          = var.app_service_port_name
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
        }
      ]
    }
  }

  prometheus_rule_manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "${var.app_name}-alerts"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        app = var.app_name
      }
    }
    spec = {
      groups = [
        {
          name = "${var.app_name}.alerts"
          rules = [
            {
              alert = "IncidentTrackerHighCPU"
              expr  = "sum(rate(container_cpu_usage_seconds_total{namespace=\"${var.app_namespace}\",pod=~\"${var.app_name}.*\",container!=\"\",container!=\"POD\"}[5m])) > 0.4"
              for   = "5m"
              labels = {
                severity = "warning"
                service  = var.app_name
              }
              annotations = {
                summary     = "High CPU on ${var.app_name} pods"
                description = "CPU usage has been above 0.4 cores for 5 minutes in namespace ${var.app_namespace}."
              }
            },
            {
              alert = "IncidentTrackerCrashLoopBackOff"
              expr  = "kube_pod_container_status_waiting_reason{namespace=\"${var.app_namespace}\",reason=\"CrashLoopBackOff\",pod=~\"${var.app_name}.*\"} > 0"
              for   = "2m"
              labels = {
                severity = "critical"
                service  = var.app_name
              }
              annotations = {
                summary     = "CrashLoopBackOff detected"
                description = "One or more ${var.app_name} pods are in CrashLoopBackOff in namespace ${var.app_namespace}."
              }
            },
            {
              alert = "IncidentTrackerRestartSpike"
              expr  = "increase(kube_pod_container_status_restarts_total{namespace=\"${var.app_namespace}\",pod=~\"${var.app_name}.*\"}[10m]) >= 3"
              for   = "0m"
              labels = {
                severity = "warning"
                service  = var.app_name
              }
              annotations = {
                summary     = "Pod restart spike detected"
                description = "${var.app_name} pods restarted 3 or more times in the last 10 minutes."
              }
            }
          ]
        }
      ]
    }
  }

  grafana_dashboard_manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "incident-tracker-dashboard"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        grafana_dashboard = "1"
      }
    }
    data = {
      "incident-tracker-overview.json" = jsonencode(local.grafana_dashboard)
    }
  }
}

resource "helm_release" "monitoring_addons" {
  name             = "monitoring-addons"
  repository       = "https://bedag.github.io/helm-charts"
  chart            = "raw"
  version          = "2.0.0"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false
  timeout          = 300
  wait             = true

  values = [
    yamlencode({
      resources = [
        local.service_monitor_manifest,
        local.prometheus_rule_manifest,
        local.grafana_dashboard_manifest
      ]
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

data "kubernetes_service_v1" "grafana" {
  metadata {
    name      = "${helm_release.kube_prometheus_stack.name}-grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  depends_on = [helm_release.kube_prometheus_stack, helm_release.monitoring_addons]
}
