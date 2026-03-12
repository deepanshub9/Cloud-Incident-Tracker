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
- The `app` module currently provides image/deployment metadata; Kubernetes resources are added in the next phase.
- Provider lock file is generated at `infra/.terraform.lock.hcl` after `terraform init`.
