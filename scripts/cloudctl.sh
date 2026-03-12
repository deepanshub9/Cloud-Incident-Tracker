#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source .env
fi

PROJECT_NAME="${PROJECT_NAME:-secure-mini-cloud}"
IMAGE_NAME="${IMAGE_NAME:-secure-mini-app}"
IMAGE_TAG="${IMAGE_TAG:-v2}"
CONTAINER_NAME="${CONTAINER_NAME:-secure-mini-app}"
APP_PORT="${APP_PORT:-8080}"
ENV_NAME="${ENV_NAME:-local}"
APP_VERSION="${APP_VERSION:-v2}"
AWS_REGION="${AWS_REGION:-us-east-2}"
ECR_REPOSITORY="${ECR_REPOSITORY:-secure-mini-app}"
INFRA_DIR="${INFRA_DIR:-infra}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-}"
EKS_NODEGROUP_NAME="${EKS_NODEGROUP_NAME:-}"

log() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH" >&2
    exit 1
  fi
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"
}

deploy_local() {
  require_cmd docker

  log "Building image ${IMAGE_NAME}:${IMAGE_TAG}"
  docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

  if container_exists; then
    log "Removing existing container ${CONTAINER_NAME}"
    docker rm -f "${CONTAINER_NAME}" >/dev/null
  fi

  log "Starting container ${CONTAINER_NAME} on http://localhost:${APP_PORT}"
  docker run -d \
    --name "${CONTAINER_NAME}" \
    -p "${APP_PORT}:8080" \
    -e "ENV_NAME=${ENV_NAME}" \
    -e "APP_VERSION=${APP_VERSION}" \
    "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null

  log "App is running"
  log "URL: http://localhost:${APP_PORT}"
  log "Health: http://localhost:${APP_PORT}/health"
}

destroy_local() {
  require_cmd docker

  if container_exists; then
    log "Removing container ${CONTAINER_NAME}"
    docker rm -f "${CONTAINER_NAME}" >/dev/null
  else
    log "Container ${CONTAINER_NAME} not found"
  fi

  log "Local deployment destroyed"
}

stop_local() {
  require_cmd docker

  if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    log "Stopping container ${CONTAINER_NAME}"
    docker stop "${CONTAINER_NAME}" >/dev/null
  else
    log "Container ${CONTAINER_NAME} is not running"
  fi
}

resume_local() {
  require_cmd docker

  if container_exists; then
    log "Starting existing container ${CONTAINER_NAME}"
    docker start "${CONTAINER_NAME}" >/dev/null
  else
    log "Container does not exist, deploying fresh"
    deploy_local
    return
  fi

  log "URL: http://localhost:${APP_PORT}"
}

aws_account_id() {
  aws sts get-caller-identity --query Account --output text
}

ecr_uri() {
  local account_id
  account_id="$(aws_account_id)"
  echo "${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"
}

ensure_ecr_repo() {
  if ! aws ecr describe-repositories --repository-names "${ECR_REPOSITORY}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    log "Creating ECR repository ${ECR_REPOSITORY}"
    aws ecr create-repository \
      --repository-name "${ECR_REPOSITORY}" \
      --image-scanning-configuration scanOnPush=true \
      --region "${AWS_REGION}" >/dev/null
  fi
}

push_image_to_ecr() {
  require_cmd aws
  require_cmd docker

  ensure_ecr_repo
  local uri
  uri="$(ecr_uri)"

  log "Authenticating Docker to ECR"
  aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${uri%/*}" >/dev/null

  log "Building image ${uri}:${IMAGE_TAG}"
  docker build -t "${uri}:${IMAGE_TAG}" .

  log "Pushing image to ECR"
  docker push "${uri}:${IMAGE_TAG}" >/dev/null

  log "Image pushed: ${uri}:${IMAGE_TAG}"
}

deploy_aws() {
  require_cmd terraform
  require_cmd aws

  if [[ ! -d "${INFRA_DIR}" ]]; then
    echo "Error: infra directory '${INFRA_DIR}' not found. Create Terraform infra first." >&2
    exit 1
  fi

  push_image_to_ecr

  log "Applying Terraform in ${INFRA_DIR}"
  terraform -chdir="${INFRA_DIR}" init
  terraform -chdir="${INFRA_DIR}" apply -auto-approve

  if [[ -n "${EKS_CLUSTER_NAME}" ]]; then
    require_cmd kubectl
    log "Updating kubeconfig for cluster ${EKS_CLUSTER_NAME}"
    aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null
    log "Kubernetes nodes:"
    kubectl get nodes || true
  fi

  log "AWS deploy complete"
}

destroy_aws() {
  require_cmd terraform

  if [[ ! -d "${INFRA_DIR}" ]]; then
    echo "Error: infra directory '${INFRA_DIR}' not found." >&2
    exit 1
  fi

  log "Destroying Terraform infra in ${INFRA_DIR}"
  terraform -chdir="${INFRA_DIR}" init
  terraform -chdir="${INFRA_DIR}" destroy -auto-approve

  log "AWS resources destroyed"
}

stop_aws() {
  require_cmd aws

  if [[ -z "${EKS_CLUSTER_NAME}" || -z "${EKS_NODEGROUP_NAME}" ]]; then
    echo "Error: set EKS_CLUSTER_NAME and EKS_NODEGROUP_NAME in .env" >&2
    exit 1
  fi

  log "Scaling node group to 0 (cost-saving stop mode)"
  aws eks update-nodegroup-config \
    --cluster-name "${EKS_CLUSTER_NAME}" \
    --nodegroup-name "${EKS_NODEGROUP_NAME}" \
    --scaling-config minSize=0,maxSize=2,desiredSize=0 \
    --region "${AWS_REGION}" >/dev/null

  log "Stop requested. Existing pods will terminate as nodes drain down."
}

resume_aws() {
  require_cmd aws

  if [[ -z "${EKS_CLUSTER_NAME}" || -z "${EKS_NODEGROUP_NAME}" ]]; then
    echo "Error: set EKS_CLUSTER_NAME and EKS_NODEGROUP_NAME in .env" >&2
    exit 1
  fi

  log "Scaling node group to desired size 1"
  aws eks update-nodegroup-config \
    --cluster-name "${EKS_CLUSTER_NAME}" \
    --nodegroup-name "${EKS_NODEGROUP_NAME}" \
    --scaling-config minSize=1,maxSize=2,desiredSize=1 \
    --region "${AWS_REGION}" >/dev/null

  log "Resume requested. Nodes will come back in a few minutes."
}

status_local() {
  require_cmd docker
  if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    log "Local app status: RUNNING (${CONTAINER_NAME})"
  elif container_exists; then
    log "Local app status: STOPPED (${CONTAINER_NAME})"
  else
    log "Local app status: NOT DEPLOYED"
  fi
}

status_aws() {
  require_cmd aws
  if [[ -z "${EKS_CLUSTER_NAME}" || -z "${EKS_NODEGROUP_NAME}" ]]; then
    echo "Set EKS_CLUSTER_NAME and EKS_NODEGROUP_NAME in .env to check AWS status." >&2
    exit 1
  fi

  aws eks describe-nodegroup \
    --cluster-name "${EKS_CLUSTER_NAME}" \
    --nodegroup-name "${EKS_NODEGROUP_NAME}" \
    --region "${AWS_REGION}" \
    --query 'nodegroup.[status,scalingConfig.desiredSize,scalingConfig.minSize,scalingConfig.maxSize]' \
    --output table
}

usage() {
  cat <<EOF
Usage:
  ./scripts/cloudctl.sh <action> <target>

Actions:
  deploy | destroy | stop | resume | status

Targets:
  local | aws

Examples:
  ./scripts/cloudctl.sh deploy local
  ./scripts/cloudctl.sh stop local
  ./scripts/cloudctl.sh resume local
  ./scripts/cloudctl.sh deploy aws
  ./scripts/cloudctl.sh stop aws
  ./scripts/cloudctl.sh resume aws
  ./scripts/cloudctl.sh destroy aws
EOF
}

ACTION="${1:-}"
TARGET="${2:-}"

if [[ -z "$ACTION" || -z "$TARGET" ]]; then
  usage
  exit 1
fi

case "${ACTION}:${TARGET}" in
  deploy:local) deploy_local ;;
  destroy:local) destroy_local ;;
  stop:local) stop_local ;;
  resume:local) resume_local ;;
  status:local) status_local ;;
  deploy:aws) deploy_aws ;;
  destroy:aws) destroy_aws ;;
  stop:aws) stop_aws ;;
  resume:aws) resume_aws ;;
  status:aws) status_aws ;;
  *)
    usage
    exit 1
    ;;
esac
