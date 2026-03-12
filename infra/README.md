# Terraform Foundation (Phase 2)

This folder provides a reusable Terraform foundation with module layout:

- `modules/network`
- `modules/eks`
- `modules/ecr`
- `modules/app`

It also includes `bootstrap/` to create remote state resources (S3 + DynamoDB).

## 1) Create remote state resources (one-time)

```bash
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply -auto-approve
terraform -chdir=infra/bootstrap output
```

Copy output values:

- `tf_state_bucket`
- `tf_lock_table`

Set them in your `.env`:

```env
TF_STATE_BUCKET=<bucket-name>
TF_STATE_DDB_TABLE=<table-name>
TF_STATE_KEY=env/dev/terraform.tfstate
```

## 2) Initialize main infra with backend

```bash
terraform -chdir=infra init \
  -backend-config="bucket=<bucket-name>" \
  -backend-config="key=env/dev/terraform.tfstate" \
  -backend-config="region=<aws-region>" \
  -backend-config="dynamodb_table=<table-name>" \
  -backend-config="encrypt=true"
```

## 3) Validate and plan

```bash
terraform -chdir=infra fmt -recursive
terraform -chdir=infra validate
terraform -chdir=infra plan -var-file=environments/dev.tfvars
```

## 4) Apply dev environment

```bash
terraform -chdir=infra apply -var-file=environments/dev.tfvars -auto-approve
```

## Phase 3 — AWS base infra (budget optimized)

This phase creates:

- VPC + public subnets + routing
- ECR repository
- EKS cluster + managed node group (Spot)
- metrics-server in the cluster

### A) Deploy dev base infra

```bash
terraform -chdir=infra apply -var-file=environments/dev.tfvars
```

### B) Configure kubectl for the new cluster

```bash
aws eks update-kubeconfig \
  --region us-east-2 \
  --name secure-mini-cloud-dev-eks
```

### C) Install metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes
```

If `kubectl top nodes` returns metrics, the addon is ready.

### D) Budget guardrails

- Keep Spot enabled in `environments/dev.tfvars` via `node_capacity_type = "SPOT"`
- Keep node size small (`t3.small`/`t3a.small`) and desired size at `1`
- Destroy when idle:

```bash
terraform -chdir=infra destroy -var-file=environments/dev.tfvars -auto-approve
```

## 5) Optional workspaces (dev/prod)

```bash
terraform -chdir=infra workspace new dev || true
terraform -chdir=infra workspace select dev
terraform -chdir=infra plan -var-file=environments/dev.tfvars

terraform -chdir=infra workspace new prod || true
terraform -chdir=infra workspace select prod
terraform -chdir=infra plan -var-file=environments/prod.tfvars
```

## 6) Destroy when needed

```bash
terraform -chdir=infra destroy -var-file=environments/dev.tfvars -auto-approve
```

## Notes

- EKS in this baseline uses public subnets and Spot node group for cost optimization.
- The `app` module now deploys Kubernetes resources via Terraform provider (`Namespace`, `Deployment`, `Service`, `HPA`).
- Provider lock file is generated at `infra/.terraform.lock.hcl` after `terraform init`.

## Phase 4 — Deploy app to EKS (Terraform Kubernetes provider)

### Required Terraform files for Kubernetes deployment

- `infra/providers.tf` (AWS + Kubernetes provider)
- `infra/modules/app/main.tf` (Namespace + Deployment + Service + HPA)
- `infra/modules/app/variables.tf` (resources/HPA inputs)
- `infra/modules/app/outputs.tf` (service/HPA outputs)

### 1) Push app image to ECR

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/secure-mini-cloud-app"

aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com"
docker build -t "$ECR_URI:v2" .
docker push "$ECR_URI:v2"
```

If you push a new tag (example `v3`), update `app_image_tag` in `infra/environments/dev.tfvars`.

### 2) Apply Terraform app deployment

```bash
terraform -chdir=infra init
terraform -chdir=infra plan -var-file=environments/dev.tfvars
terraform -chdir=infra apply -var-file=environments/dev.tfvars
```

### 3) Validate endpoint

```bash
kubectl get svc -n dev incident-tracker
kubectl get hpa -n dev incident-tracker-hpa
terraform -chdir=infra output app_service_lb_hostname
```

When the LoadBalancer hostname is ready, test:

```bash
curl http://<load-balancer-hostname>/health
```

### 4) Validate autoscaling on CPU

Ensure metrics-server is installed first, then run:

```bash
kubectl top pods -n dev
kubectl get hpa -n dev -w
```

Generate load from inside cluster:

```bash
kubectl run loadgen --rm -it --restart=Never --image=busybox:1.36 -- /bin/sh -c "while true; do wget -q -O- http://incident-tracker.dev.svc.cluster.local/health >/dev/null; done"
```

Expected: HPA increases replicas above 1 when CPU usage crosses target.

## Phase 5 — Kubernetes security hardening

This phase applies:

- Multi-tenancy namespaces: `dev` and `prod`
- Resource quotas and default limit ranges per namespace
- RBAC least privilege (`dev` read-only, `prod` operator role)
- Optional over-privilege simulation (`cluster-admin`) and rollback
- NetworkPolicy default deny + explicit allow rules
- Pod Security Admission namespace labels (`restricted`)

### 1) Apply security hardening

```bash
terraform -chdir=infra plan -var-file=environments/dev.tfvars
terraform -chdir=infra apply -var-file=environments/dev.tfvars
```

### 2) Verify namespaces and Pod Security labels

```bash
kubectl get ns dev prod --show-labels
```

You should see:

- `pod-security.kubernetes.io/enforce=restricted`
- `pod-security.kubernetes.io/audit=restricted`
- `pod-security.kubernetes.io/warn=restricted`

### 3) Verify quotas and limits

```bash
kubectl get resourcequota -n dev
kubectl get resourcequota -n prod
kubectl get limitrange -n dev
kubectl get limitrange -n prod
```

### 4) Verify RBAC least privilege

```bash
kubectl auth can-i list pods --as=system:serviceaccount:dev:dev-reader -n dev
kubectl auth can-i create deployment --as=system:serviceaccount:dev:dev-reader -n dev
kubectl auth can-i create deployment --as=system:serviceaccount:prod:prod-operator -n prod
kubectl auth can-i create clusterrole --as=system:serviceaccount:prod:prod-operator
```

Expected:

- dev-reader: read allowed, write denied
- prod-operator: namespace-level create/update allowed, cluster-wide admin denied

### 5) Over-privilege simulation (cluster-admin) then fix

Temporarily set in `infra/environments/dev.tfvars`:

```hcl
simulate_overprivilege = true
```

Apply and verify escalation:

```bash
terraform -chdir=infra apply -var-file=environments/dev.tfvars
kubectl auth can-i create clusterrole --as=system:serviceaccount:prod:prod-operator
```

Then fix by reverting:

```hcl
simulate_overprivilege = false
```

```bash
terraform -chdir=infra apply -var-file=environments/dev.tfvars
kubectl auth can-i create clusterrole --as=system:serviceaccount:prod:prod-operator
```

Expected after fix: `no`

### 6) Verify NetworkPolicies

```bash
kubectl get networkpolicy -n dev
kubectl get networkpolicy -n prod
kubectl describe networkpolicy default-deny-all -n dev
kubectl describe networkpolicy default-deny-all -n prod
```
