# Cloud Incident Tracker App

Welcome! This practical DevOps/SRE learning app.  
It helps you simulate real production incidents, monitor them, respond to alerts, and verify recovery.

The goal is simple: learn the full incident lifecycle in a safe way, from “issue created” to “issue resolved.”

## What this application does

This is a web-based incident tracker built with Flask and SQLite.

You can:

- Create incidents for services such as payments, auth, and orders
- Assign severity levels (`P1` to `P4`)
- Resolve incidents when recovery is done
- View live counters (open, resolved, and by severity)
- Expose Prometheus metrics for monitoring dashboards and alerts

This makes it useful for both app developers and platform/operations teams.

## Who should use this project

- **Beginners**: learn API basics, Docker usage, and simple incident workflow
- **Intermediate users**: practice Kubernetes operations, observability, and scripting
- **Advanced users**: run realistic incident drills (RBAC failures, OOM behavior, alert response)

## Application and Monitoring Screenshots

### 1. Grafana Data Sources

[![Grafana Data Sources](https://github.com/user-attachments/assets/bf6ced0b-0266-42bf-81fe-6f76733ba5f9)](https://github.com/user-attachments/assets/bf6ced0b-0266-42bf-81fe-6f76733ba5f9)

### 2. Prometheus Targets / Metrics View

[![Prometheus Targets](https://github.com/user-attachments/assets/4a78ae33-e847-414e-8e38-e17d26c47d48)](https://github.com/user-attachments/assets/4a78ae33-e847-414e-8e38-e17d26c47d48)

### 3. Alertmanager Configuration

[![Alertmanager Configuration](https://github.com/user-attachments/assets/a6675001-e0da-4a46-9239-a05474b89e87)](https://github.com/user-attachments/assets/a6675001-e0da-4a46-9239-a05474b89e87)

### 4. Grafana Dashboard / Monitoring Overview

[![Grafana Dashboard](https://github.com/user-attachments/assets/79e5c097-aa4e-41a3-bcb4-448cb2148816)](https://github.com/user-attachments/assets/79e5c097-aa4e-41a3-bcb4-448cb2148816)

## How the system is organized

At a high level, the project has four layers:

1. **Application layer**: Flask UI + REST APIs + SQLite incident storage
2. **Container layer**: Docker image and runtime settings
3. **Infrastructure layer**: Terraform modules for AWS/EKS networking, security, and observability
4. **Operations layer**: phase-based scripts and manifests for troubleshooting and incident simulation

## Project structure (explained)

### Root files

- `README.md`  
  Main documentation and operational guide.
- `requirements.txt`  
  Python package dependencies used by the Flask app.
- `Dockerfile`  
  Container build definition for running the app consistently across environments.

### `app/` — Application module

- `app/main.py`  
  Core backend module. It handles:
  - database initialization and access
  - incident CRUD-style workflows (create/list/resolve)
  - summary generation (open/resolved/severity counts)
  - metrics refresh for Prometheus
  - health/info endpoints used by Kubernetes and monitoring
- `app/templates/index.html`  
  Frontend dashboard page for human users to view and manage incidents.
- `app/__init__.py`  
  Package marker for Python module structure.

### `data/` — Local persistence

- Stores the SQLite database file (`incidents.db`) at runtime.
- Keeps local state simple for fast learning and testing.

### `infra/` — Infrastructure as Code module set

- `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `versions.tf`  
  Terraform root configuration that composes all modules.
- `backend.tf`  
  State backend configuration pattern (local or remote state strategy).
- `environments/dev.tfvars`, `environments/prod.tfvars`  
  Environment-specific values.
- `bootstrap/`  
  Initial Terraform setup helpers (commonly used for backend prerequisites).

#### `infra/modules/` (each module purpose)

- `network/` — VPC/subnet/network foundation
- `security/` — IAM/security controls and related guardrails
- `eks/` — Kubernetes control plane and worker node infrastructure
- `ecr/` — Container registry for application images
- `app/` — Application deployment resources on Kubernetes/cloud layer
- `observability/` — Prometheus/Grafana/monitoring integrations and exposure

### `ops/` — Operations and incident labs

- `ops/phase7/`  
  Linux/runtime troubleshooting assets (sysctl hardening + OOM simulation).
- `ops/phase8/`  
  Incident-response drill assets (RBAC break, detection, recovery, postmortem).

### `scripts/` — Automation module

- `scripts/cloudctl.sh`  
  One-command lifecycle operations for local and AWS flows (`deploy`, `stop`, `resume`, `destroy`, `status`).
- `scripts/phase7-runtime-lab.sh`  
  Guided runtime troubleshooting workflow (`apply-sysctl`, `validate-runtime`, `run-oom`, `cleanup`, `full`).
- `scripts/phase8-incident-response.sh`  
  End-to-end incident drill workflow (`install`, `break`, `detect`, `fix`, `verify`, `cleanup`, `full`).

## API overview (what each endpoint means)

- `GET /health`  
  Simple readiness/liveness style check.
- `GET /api/info`  
  Runtime metadata (app name, environment, version, host, UTC time).
- `GET /api/summary`  
  Aggregate incident counts and severity snapshot.
- `GET /api/incidents?status=open|resolved|all`  
  Incident listing filtered by status.
- `POST /api/incidents`  
  Create a new incident.
- `PATCH /api/incidents/<id>/resolve`  
  Mark an open incident as resolved.
- `GET /metrics`  
  Prometheus metrics endpoint for dashboards and alerts.

## Quick usage guide

- Local lifecycle commands are managed through `scripts/cloudctl.sh`.
- AWS lifecycle commands are also managed through `scripts/cloudctl.sh` (with Terraform + ECR + EKS context).
- Phase drills are run with `scripts/phase7-runtime-lab.sh` and `scripts/phase8-incident-response.sh`.

If you are new, start local first, then move to AWS and phase drills.

## Why this project is useful

This repository is more than a sample app. It is a complete learning path for:

- application reliability thinking
- operational debugging
- monitoring and alert design
- incident communication and recovery discipline

In short: it teaches both **how to build** and **how to operate** production-minded systems.
