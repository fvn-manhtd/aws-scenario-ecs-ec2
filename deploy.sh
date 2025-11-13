#!/bin/bash

## Simulated hash per deployment, normally used by CI/CD system
HASH=$(openssl rand -hex 12)

cd infra

## Initialize Terraform
terraform init

## Optionally select or create workspace from ENVIRONMENT to allow parallel envs
if [ -n "${ENVIRONMENT:-}" ]; then
  if terraform workspace select "${ENVIRONMENT}" >/dev/null 2>&1; then
    printf '%s\n' "Using terraform workspace '${ENVIRONMENT}'." >&2
  else
    terraform workspace new "${ENVIRONMENT}"
    printf '%s\n' "Created terraform workspace '${ENVIRONMENT}'." >&2
  fi
fi

## Generate Terraform plan file
terraform plan -var hash=${HASH} -out=infrastructure.tf.plan

## Provision resources
terraform apply -auto-approve infrastructure.tf.plan
rm -rf infrastructure.tf.plan

## Read ECR repository URL to push Docker image with app to registry
REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
REPOSITORY_BASE_URL=$(sed -r 's#([^/])/[^/].*#\1#' <<< ${REPOSITORY_URL})
REGION=$(terraform output -raw region)
aws ecr get-login-password --region ${REGION} | \
    docker login --username AWS --password-stdin ${REPOSITORY_BASE_URL}

## Build Docker image and tag new versions for every deployment
# Allow overriding the local image namespace via .env (exported by Makefile)
# If LOCAL_IMAGE_NAMESPACE is empty/unset, build without a namespace prefix
IMAGE_NAME="$1"
if [ -n "${LOCAL_IMAGE_NAMESPACE}" ]; then
    LOCAL_IMAGE_TAG="${LOCAL_IMAGE_NAMESPACE}/${IMAGE_NAME}"
else
    LOCAL_IMAGE_TAG="${IMAGE_NAME}"
fi

docker build --platform linux/amd64 -t "${LOCAL_IMAGE_TAG}" ../app
docker tag "${LOCAL_IMAGE_TAG}:latest" "${REPOSITORY_URL}:latest"
docker tag "${LOCAL_IMAGE_TAG}:latest" "${REPOSITORY_URL}:${HASH}"
docker push ${REPOSITORY_URL}:latest
docker push ${REPOSITORY_URL}:${HASH}
