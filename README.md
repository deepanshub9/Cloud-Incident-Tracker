# Cloud Incident Tracker App

This repository now contains a **real-use-case app**: a cloud incident tracker for DevOps/SRE practice.

## Use case

Track production incidents for services (payments, auth, orders), then resolve them. This maps directly to your monitoring + incident response flow on AWS/EKS.

## Features

- Incident dashboard UI
- Create incidents with severity (P1-P4)
- Mark incidents as resolved
- Live counters (open, resolved, P1/P2/P3/P4)
- API endpoints for integration/testing
- Health endpoint for Kubernetes probes

## Project structure

- `app/main.py` - Flask backend + SQLite APIs
- `app/templates/index.html` - interactive incident dashboard
- `requirements.txt` - Python dependencies
- `Dockerfile` - secure container image

## APIs

- `GET /health`
- `GET /api/info`
- `GET /api/summary`
- `GET /api/incidents?status=open|resolved|all`
- `POST /api/incidents`
- `PATCH /api/incidents/<id>/resolve`

Example payload for create:

```json
{
  "service": "payments-api",
  "title": "High error rate",
  "severity": "P1",
  "description": "5xx spike after deployment"
}
```

## Run locally (without Docker)

1. Create virtual environment
   - Windows PowerShell:
     - `python -m venv .venv`
     - `.\.venv\Scripts\Activate.ps1`
2. Install dependencies
   - `pip install -r requirements.txt`
3. Start app
   - `python app/main.py`
4. Open in browser
   - `http://localhost:8080`

## Run with Docker

1. Build image
   - `docker build -t secure-mini-app:v2 .`
2. Start container
   - `docker run --rm -p 8080:8080 -e ENV_NAME=local -e APP_VERSION=v2 secure-mini-app:v2`
3. Open browser
   - `http://localhost:8080`

## Why this is better for your AWS project

- Works naturally with Prometheus/Grafana (incident metrics view)
- Good for RBAC demo (read-only vs incident manager)
- Good for incident simulation (create P1, observe, resolve, postmortem)

## One-click operations (deploy / destroy / stop / resume)

Use the control script at [scripts/cloudctl.sh](scripts/cloudctl.sh).

### 1) Setup config once

1. Copy [.env.example](.env.example) to `.env`
2. Edit values in `.env` (AWS region, repository, cluster names later)

### 2) Local one-click lifecycle

- Deploy app locally:
  - `bash scripts/cloudctl.sh deploy local`
- Stop local app (keep container):
  - `bash scripts/cloudctl.sh stop local`
- Resume local app:
  - `bash scripts/cloudctl.sh resume local`
- Destroy local app:
  - `bash scripts/cloudctl.sh destroy local`
- Check local status:
  - `bash scripts/cloudctl.sh status local`

### 3) AWS one-click lifecycle (after Terraform infra is added)

- Deploy AWS (push image to ECR + terraform apply):
  - `bash scripts/cloudctl.sh deploy aws`
- Stop AWS cost (scale EKS node group to zero):
  - `bash scripts/cloudctl.sh stop aws`
- Resume AWS (scale EKS node group back to one):
  - `bash scripts/cloudctl.sh resume aws`
- Destroy AWS infra:
  - `bash scripts/cloudctl.sh destroy aws`
- Check AWS node group status:
  - `bash scripts/cloudctl.sh status aws`

### Notes

- For `stop aws` / `resume aws`, set `EKS_CLUSTER_NAME` and `EKS_NODEGROUP_NAME` in `.env`.
- `deploy aws` expects Terraform files under the `infra` directory (`INFRA_DIR` can be changed in `.env`).

## Phase 7 — Linux/runtime troubleshooting lab

This phase gives hands-on ops troubleshooting skills on EKS nodes and containers.

### What is included

- Host sysctl hardening profile as DaemonSet:
  - `ops/phase7/00-sysctl-hardening-daemonset.yaml`
- OOM simulation deployment:
  - `ops/phase7/10-oom-sim-deployment.yaml`
- One-command lab runner:
  - `scripts/phase7-runtime-lab.sh`

### Run the full lab

```bash
bash scripts/phase7-runtime-lab.sh full
```

### Run step-by-step

1. Apply host sysctl hardening and verify effective values:

```bash
bash scripts/phase7-runtime-lab.sh apply-sysctl
```

2. Validate runtime behavior on the real app pod:

```bash
bash scripts/phase7-runtime-lab.sh validate-runtime
```

3. Run OOM simulation and inspect debug evidence (`describe`, events, logs):

```bash
bash scripts/phase7-runtime-lab.sh run-oom
```

4. Clean up lab resources:

```bash
bash scripts/phase7-runtime-lab.sh cleanup
```

### What to look for (expected outcomes)

- Sysctl verification outputs should show:
  - `kernel.kptr_restrict=2`
  - `kernel.dmesg_restrict=1`
  - `net.ipv4.conf.all.rp_filter=1`
  - `net.ipv4.conf.default.rp_filter=1`
  - `net.ipv4.tcp_syncookies=1`
- OOM simulation should show `OOMKilled` in pod state or last state.
- `kubectl describe pod` should contain memory limit and container restart signals.
- `kubectl logs --previous` should help confirm restart cycle behavior.
