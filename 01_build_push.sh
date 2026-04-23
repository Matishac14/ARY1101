#!/bin/bash
# ==============================================================================
# SCRIPT 01 — Build Docker Images → ECR + Terraform Apply
# ARY1101 · Matias Fernandez
# Uso: ./01_build_push.sh
# Pre-requisitos: AWS CLI configurado, Docker corriendo, Terraform instalado
# ==============================================================================
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
API_REPOS=("technova-api-productos" "technova-api-pedidos")

echo "========================================================"
echo " TechNova POC — Build & Deploy"
echo " Cuenta: $ACCOUNT_ID | Region: $REGION"
echo "========================================================"

echo ""
echo ">> [1/4] Autenticando con ECR..."
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin \
  "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
echo "   ✅ Login ECR OK"

echo ""
echo ">> [2/4] Creando repositorios ECR (solo APIs — frontend va a S3)..."
for REPO in "${API_REPOS[@]}"; do
  aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" \
    > /dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$REPO" --region "$REGION" > /dev/null
  echo "   ✅ ECR repo: $REPO"
done

echo ""
echo ">> [3/4] Build & Push de imágenes API..."
for REPO in "${API_REPOS[@]}"; do
  if [ ! -d "./$REPO" ]; then
    echo "   ⚠️  Directorio ./$REPO no encontrado, omitiendo..."
    continue
  fi
  echo "   Building $REPO..."
  docker build -t "$REPO:latest" "./$REPO"
  docker tag "${REPO}:latest" \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:latest"
  docker push \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:latest"
  echo "   ✅ $REPO pushed a ECR"
done

echo ""
echo ">> [4/4] Aplicando infraestructura con Terraform..."
terraform init -input=false
terraform apply -auto-approve

echo ""
echo "========================================================"
echo "✅ Infraestructura lista."
echo ""
echo "  ALB (APIs):  $(terraform output -raw alb_dns_name)"
echo "  RDS:         $(terraform output -raw rds_endpoint)"
echo "  EC2 ID:      $(terraform output -raw ec2_instance_id)"
echo "  S3 URL:      $(terraform output -raw s3_website_url)"
echo "  S3 Bucket:   $(terraform output -raw s3_bucket_name)"
echo ""
echo "Espera ~2 min para que el user_data del EC2 finalice."
echo "Luego ejecuta: ./02_deploy_app.sh"
echo "========================================================"
