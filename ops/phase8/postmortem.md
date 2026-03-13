# Phase 8 Postmortem: dev-reader RBAC Regression

- Incident: `DevReaderRBACDenied`
- Date: 2026-03-13
- Impact: The monitoring smokecheck lost read-only access to pods in `dev`, so it exported `rbac_smokecheck_denied=1` and triggered the Phase 8 critical alert until the binding was restored.
- Root cause: The `rbac-smokecheck-readonly` RoleBinding in `dev` was intentionally removed during the response drill.
- Detection: Prometheus observed `rbac_smokecheck_denied=1` for the smokecheck exporter and the `DevReaderRBACDenied` alert fired. The Grafana `Incident Response Drill` dashboard showed the same denial state.
- Resolution: Re-applied `rbac-smokecheck-readonly`, restoring the smokecheck service account's `readonly` access to `dev` pods.
- Verification: Prometheus returned `rbac_smokecheck_denied=0` again and the alert cleared after recovery.
- Prevention: Treat RBAC bindings as release-critical configuration and keep a synthetic permission smokecheck in monitoring for least-privilege service accounts.
