#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALERT_FILE="$ROOT_DIR/ops/phase8/00-incident-target-down-alert.yaml"
RBAC_FILE="$ROOT_DIR/ops/phase8/10-rbac-smokecheck-rbac.yaml"
STACK_FILE="$ROOT_DIR/ops/phase8/15-rbac-smokecheck-stack.yaml"
DASHBOARD_FILE="$ROOT_DIR/ops/phase8/20-incident-response-dashboard.yaml"

log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: command '$1' not found" >&2
    exit 1
  fi
}

prom_url() {
  local host
  host=$(kubectl -n monitoring get svc monitoring-prometheus-external -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  echo "http://$host"
}

grafana_url() {
  local host
  host=$(kubectl -n monitoring get svc monitoring-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  echo "http://$host"
}

query_prom() {
  local query="$1"
  curl -fsS "$(prom_url)/api/v1/query" --data-urlencode "query=$query"
}

install_assets() {
  log "Temporarily scaling CoreDNS to 1 to free pod capacity for the drill"
  kubectl -n kube-system scale deployment coredns --replicas=1 >/dev/null

  log "Installing Phase 8 smokecheck, alert rule, and dashboard"
  kubectl apply -f "$RBAC_FILE"
  kubectl apply -f "$STACK_FILE"
  kubectl apply -f "$ALERT_FILE"
  kubectl apply -f "$DASHBOARD_FILE"

  log "Waiting for smokecheck rollout"
  kubectl -n monitoring rollout status deployment/rbac-smokecheck --timeout=180s

  log "Waiting for PrometheusRule to be visible"
  kubectl -n monitoring get prometheusrule incident-tracker-phase8-alerts >/dev/null

  log "Waiting for Grafana dashboard sidecar sync"
  sleep 10
}

break_policy() {
  log "Deleting rbac-smokecheck-readonly to break monitoring access to dev pods"
  kubectl -n dev delete rolebinding rbac-smokecheck-readonly --ignore-not-found
}

detect_incident() {
  local prom
  prom=$(prom_url)

  log "Waiting for rbac_smokecheck_denied to flip to 1"
  for _ in $(seq 1 18); do
    if query_prom 'rbac_smokecheck_denied' | grep -q '"value":\[[^]]*,"1"\]'; then
      break
    fi
    sleep 10
  done

  log "Waiting for DevReaderRBACDenied alert to fire"
  for _ in $(seq 1 18); do
    if curl -fsS "$prom/api/v1/alerts" | grep -q 'DevReaderRBACDenied'; then
      break
    fi
    sleep 10
  done

  echo "--- Prometheus RBAC smokecheck metric ---"
  query_prom 'rbac_smokecheck_denied'
  echo
  echo "--- Active alerts ---"
  curl -fsS "$prom/api/v1/alerts"
  echo
  echo "--- Grafana dashboard search ---"
  curl -fsS -u 'admin:ChangeMe-Observability-123!' "$(grafana_url)/api/search?query=Incident%20Response%20Drill"
  echo
}

fix_incident() {
  log "Re-applying rbac-smokecheck-readonly to restore monitoring access"
  kubectl apply -f "$RBAC_FILE"
}

verify_recovery() {
  local prom
  prom=$(prom_url)

  log "Waiting for rbac_smokecheck_denied to return to 0"
  for _ in $(seq 1 18); do
    if query_prom 'rbac_smokecheck_denied' | grep -q '"value":\[[^]]*,"0"\]'; then
      break
    fi
    sleep 10
  done

  log "Waiting for DevReaderRBACDenied to clear"
  for _ in $(seq 1 18); do
    if ! curl -fsS "$prom/api/v1/alerts" | grep -q 'DevReaderRBACDenied'; then
      break
    fi
    sleep 10
  done

  echo "--- Prometheus RBAC smokecheck metric after fix ---"
  query_prom 'rbac_smokecheck_denied'
  echo
  echo "--- Active alerts after fix ---"
  curl -fsS "$prom/api/v1/alerts"
  echo
}

cleanup_assets() {
  log "Cleaning up Phase 8 smokecheck resources and restoring CoreDNS"
  kubectl apply -f "$RBAC_FILE" >/dev/null
  kubectl -n monitoring delete -f "$STACK_FILE" --ignore-not-found >/dev/null
  kubectl -n kube-system scale deployment coredns --replicas=2 >/dev/null
}

usage() {
  cat <<EOF
Usage: bash scripts/phase8-incident-response.sh <command>

Commands:
  install    Deploy the RBAC smokecheck, alert, and dashboard
  break      Delete the smokecheck RoleBinding in dev
  detect     Wait for the smokecheck metric and alert to flip
  fix        Re-apply the smokecheck RoleBinding
  verify     Wait for recovery and alert clearance
  cleanup    Delete the smokecheck resources and restore CoreDNS
  full       Run install + break + detect + fix + verify
EOF
}

main() {
  require_cmd kubectl
  require_cmd curl

  local cmd="${1:-}"
  case "$cmd" in
    install)
      install_assets
      ;;
    break)
      break_policy
      ;;
    detect)
      detect_incident
      ;;
    fix)
      fix_incident
      ;;
    verify)
      verify_recovery
      ;;
    cleanup)
      cleanup_assets
      ;;
    full)
      install_assets
      break_policy
      detect_incident
      fix_incident
      verify_recovery
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"