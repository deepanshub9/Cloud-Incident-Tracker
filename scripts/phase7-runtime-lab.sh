#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSCTL_FILE="$ROOT_DIR/ops/phase7/00-sysctl-hardening-daemonset.yaml"
OOM_FILE="$ROOT_DIR/ops/phase7/10-oom-sim-deployment.yaml"

log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: command '$1' not found" >&2
    exit 1
  fi
}

apply_sysctl() {
  log "Applying host sysctl hardening DaemonSet"
  kubectl apply -f "$SYSCTL_FILE"

  log "Waiting for DaemonSet rollout"
  kubectl -n kube-system rollout status ds/node-sysctl-hardening --timeout=180s

  log "Verifying values from one pod"
  local pod
  pod=$(kubectl -n kube-system get pod -l app=node-sysctl-hardening -o jsonpath='{.items[0].metadata.name}')

  kubectl -n kube-system exec "$pod" -- chroot /host /sbin/sysctl -n kernel.kptr_restrict
  kubectl -n kube-system exec "$pod" -- chroot /host /sbin/sysctl -n kernel.dmesg_restrict
  kubectl -n kube-system exec "$pod" -- chroot /host /sbin/sysctl -n net.ipv4.conf.all.rp_filter
  kubectl -n kube-system exec "$pod" -- chroot /host /sbin/sysctl -n net.ipv4.conf.default.rp_filter
  kubectl -n kube-system exec "$pod" -- chroot /host /sbin/sysctl -n net.ipv4.tcp_syncookies
}

validate_runtime() {
  log "Validating runtime behavior on incident-tracker pod"
  local pod
  pod=$(kubectl -n dev get pod -l app=incident-tracker -o jsonpath='{.items[0].metadata.name}')

  echo "--- Pod info ---"
  kubectl -n dev get pod "$pod" -o wide

  echo "--- Security context (effective) ---"
  kubectl -n dev get pod "$pod" -o jsonpath='{.spec.securityContext}' && echo
  kubectl -n dev get pod "$pod" -o jsonpath='{.spec.containers[0].securityContext}' && echo

  echo "--- Cgroup / limits from inside container ---"
  kubectl -n dev exec "$pod" -- sh -c 'id && cat /proc/1/cgroup | head -n 20'

  echo "--- Recent kube events in dev ---"
  kubectl -n dev get events --sort-by=.lastTimestamp | tail -n 20
}

run_oom() {
  log "Creating OOM simulation deployment"
  kubectl apply -f "$OOM_FILE"

  log "Waiting up to 90s to observe OOMKilled state"
  sleep 15
  for _ in $(seq 1 10); do
    if kubectl -n dev get pod -l app=oom-lab -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null | grep -q OOMKilled; then
      break
    fi
    sleep 8
  done

  local pod
  pod=$(kubectl -n dev get pod -l app=oom-lab -o jsonpath='{.items[0].metadata.name}')

  echo "--- OOM pod summary ---"
  kubectl -n dev get pod "$pod"

  echo "--- kubectl describe (key signals) ---"
  kubectl -n dev describe pod "$pod" | sed -n '/State:/,/Events:/p'

  echo "--- Previous container logs ---"
  kubectl -n dev logs "$pod" --previous || true

  echo "--- Events filtered for oom-lab ---"
  kubectl -n dev get events --sort-by=.lastTimestamp | grep -i 'oom-lab\|OOM\|Killing' || true
}

cleanup_lab() {
  log "Cleaning up Phase 7 lab resources"
  kubectl -n dev delete -f "$OOM_FILE" --ignore-not-found
  kubectl -n kube-system delete -f "$SYSCTL_FILE" --ignore-not-found
}

usage() {
  cat <<EOF
Usage: bash scripts/phase7-runtime-lab.sh <command>

Commands:
  apply-sysctl       Apply host sysctl hardening profile and verify values
  validate-runtime   Validate container runtime behavior on incident-tracker pod
  run-oom            Run OOM simulation and print debug evidence
  cleanup            Delete lab resources
  full               Run apply-sysctl + validate-runtime + run-oom
EOF
}

main() {
  require_cmd kubectl
  local cmd="${1:-}"
  case "$cmd" in
    apply-sysctl)
      apply_sysctl
      ;;
    validate-runtime)
      validate_runtime
      ;;
    run-oom)
      run_oom
      ;;
    cleanup)
      cleanup_lab
      ;;
    full)
      apply_sysctl
      validate_runtime
      run_oom
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
