#!/bin/bash
# ==============================================================================
# Script de CI/CD (Mock) para compilar y subir imágenes a Amazon ECR
# REQUISITOS: AWS CLI configurado con las credenciales temporales del Learner Lab
# ==============================================================================

# Detener ejecución si hay errores
set -e

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo ">> Creando repositorios ECR si no existen..."
aws ecr describe-repositories --repository-names technova-frontend || aws ecr create-repository --repository-name technova-frontend
aws ecr describe-repositories --repository-names technova-api-productos || aws ecr create-repository --repository-name technova-api-productos
aws ecr describe-repositories --repository-names technova-api-pedidos || aws ecr create-repository --repository-name technova-api-pedidos

echo ">> Autenticando Docker en AWS ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

echo ">> Compilando imágenes localmente..."
# Asegúrate de estar en el directorio raíz del repositorio ARY1101
docker build -t technova-frontend ./technova-frontend
docker build -t technova-api-productos ./technova-api-productos
docker build -t technova-api-pedidos ./technova-api-pedidos

echo ">> Etiquetando imágenes (Tagging)..."
docker tag technova-frontend:latest $ECR_URI/technova-frontend:latest
docker tag technova-api-productos:latest $ECR_URI/technova-api-productos:latest
docker tag technova-api-pedidos:latest $ECR_URI/technova-api-pedidos:latest

echo ">> Subiendo imágenes a ECR (Push)..."
docker push $ECR_URI/technova-frontend:latest
docker push $ECR_URI/technova-api-productos:latest
docker push $ECR_URI/technova-api-pedidos:latest

echo ">> ¡Completado! Las imágenes están listas en AWS ECR."
echo ">> Ahora puedes ejecutar 'terraform apply' para levantar el clúster ECS."