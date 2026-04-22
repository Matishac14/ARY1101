#!/bin/bash
# ==============================================================================
# SCRIPT 1: ECR PRE-DEPLOY & TERRAFORM APPLY
# ==============================================================================
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPOS=("technova-frontend" "technova-api-productos" "technova-api-pedidos")

echo ">> 1. Autenticando con ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

echo ">> 2. Verificando/Creando Repositorios ECR..."
for REPO in "${REPOS[@]}"; do
    aws ecr describe-repositories --repository-names $REPO --region $REGION > /dev/null 2>&1 || \
    aws ecr create-repository --repository-name $REPO --region $REGION > /dev/null
done

echo ">> 3. Compilando y subiendo imágenes..."
for REPO in "${REPOS[@]}"; do
    echo " -> Procesando $REPO..."
    docker build -t $REPO ./$REPO
    docker tag $REPO:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
    docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
done

echo ">> 4. Aplicando Infraestructura Terraform..."
terraform apply -auto-approve

echo ">> ¡Despliegue de Infraestructura Completado!"
echo ">> Ejecuta ahora ./02_inject_db.sh"