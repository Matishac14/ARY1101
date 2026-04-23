#!/bin/bash
# ==============================================================================
# SCRIPT 02 — Deploy: init.sql → RDS + containers API → EC2 + frontend → S3
# ARY1101 · Matias Fernandez
# Uso: ./02_deploy_app.sh
# Sin SSH. Sin S3 para código. Todo vía SSM Session Manager + aws s3 sync.
# ==============================================================================
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DB_NAME="tienda_20099194"
DB_USER="admin"
DB_PASS="20099194k"
INIT_SQL="./technova-db/init.sql"

echo "========================================================"
echo " TechNova POC — Despliegue de Aplicación"
echo "========================================================"

echo ""
echo ">> [1/5] Leyendo outputs de Terraform..."
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
INSTANCE_ID=$(terraform output -raw ec2_instance_id)
ALB_URL=$(terraform output -raw alb_dns_name)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
S3_URL=$(terraform output -raw s3_website_url)
echo "   EC2:    $INSTANCE_ID"
echo "   RDS:    $RDS_ENDPOINT"
echo "   ALB:    $ALB_URL"
echo "   Bucket: $S3_BUCKET"

echo ""
echo ">> [2/5] Esperando SSM Agent en EC2 (max 5 min)..."
SSM_OK=false
for i in $(seq 1 10); do
  STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --region "$REGION" \
    --query "InstanceInformationList[0].PingStatus" \
    --output text 2>/dev/null || echo "")
  if [ "$STATUS" = "Online" ]; then
    echo "   ✅ SSM Agent Online"
    SSM_OK=true
    break
  fi
  echo "   Intento $i/10 — esperando 30s..."
  sleep 30
done
if [ "$SSM_OK" != "true" ]; then
  echo "❌ SSM Agent no respondió. Verifica que LabInstanceProfile esté adjunto al EC2."
  exit 1
fi

echo ""
echo ">> [3/5] Inyectando init.sql en RDS via SSM..."
[ ! -f "$INIT_SQL" ] && echo "❌ No existe $INIT_SQL" && exit 1

# Enviar SQL en base64 para evitar problemas con caracteres especiales
SQL_B64=$(base64 < "$INIT_SQL" | tr -d '\n')
CMD_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=InstanceIds,Values=$INSTANCE_ID" \
  --parameters "commands=[
    \"echo '$SQL_B64' | base64 -d > /tmp/init.sql\",
    \"mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS $DB_NAME < /tmp/init.sql && echo 'SQL_OK' || echo 'SQL_ERROR'\",
    \"mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS $DB_NAME -e 'SHOW TABLES;'\",
    \"rm -f /tmp/init.sql\"
  ]" \
  --timeout-seconds 90 \
  --region "$REGION" \
  --query "Command.CommandId" --output text)
echo "   CommandId: $CMD_ID — esperando 20s..."
sleep 20
aws ssm get-command-invocation \
  --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query "StandardOutputContent" --output text

echo ""
echo ">> [4/5] Desplegando containers API en EC2 via SSM..."
CMD_ID2=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=InstanceIds,Values=$INSTANCE_ID" \
  --parameters "commands=[
    \"aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\",
    \"docker rm -f technova-api-productos technova-api-pedidos 2>/dev/null || true\",
    \"docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/technova-api-productos:latest\",
    \"docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/technova-api-pedidos:latest\",
    \"docker run -d --name technova-api-productos --restart unless-stopped -p 3001:3001 -e DB_HOST=$RDS_ENDPOINT -e DB_USER=$DB_USER -e DB_PASSWORD=$DB_PASS -e DB_NAME=$DB_NAME -e ALUMNO_NOMBRE='Matias Fernandez' -e ALUMNO_RUT='20.099.194-k' -e ALUMNO_SECCION='ARY1101' $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/technova-api-productos:latest\",
    \"docker run -d --name technova-api-pedidos --restart unless-stopped -p 3002:3002 -e DB_HOST=$RDS_ENDPOINT -e DB_USER=$DB_USER -e DB_PASSWORD=$DB_PASS -e DB_NAME=$DB_NAME -e ALUMNO_NOMBRE='Matias Fernandez' -e ALUMNO_RUT='20.099.194-k' -e ALUMNO_SECCION='ARY1101' $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/technova-api-pedidos:latest\",
    \"sleep 5 && docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'\"
  ]" \
  --timeout-seconds 180 \
  --region "$REGION" \
  --query "Command.CommandId" --output text)
echo "   CommandId: $CMD_ID2 — esperando 40s..."
sleep 40
aws ssm get-command-invocation \
  --command-id "$CMD_ID2" --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query "StandardOutputContent" --output text

echo ""
echo ">> [5/5] Subiendo frontend estático a S3..."
# El frontend debe tener ALB_URL configurado en su JS antes del build
# Si usas una variable de entorno o archivo de config, actualízala aquí:
if [ -d "./technova-frontend/dist" ]; then
  FRONTEND_DIR="./technova-frontend/dist"
elif [ -d "./technova-frontend/build" ]; then
  FRONTEND_DIR="./technova-frontend/build"
else
  FRONTEND_DIR="./technova-frontend"
fi
echo "   Sincronizando $FRONTEND_DIR → s3://$S3_BUCKET/"
aws s3 sync "$FRONTEND_DIR" "s3://$S3_BUCKET/" \
  --delete \
  --region "$REGION"
echo "   ✅ Frontend publicado en S3"

echo ""
echo "========================================================"
echo "✅ APLICACIÓN DESPLEGADA"
echo ""
echo "  Frontend: $S3_URL"
echo "  API:      $ALB_URL/api/productos/info"
echo "  API:      $ALB_URL/api/pedidos/info"
echo ""
echo "Ejecuta: ./03_validate.sh para validar todo."
echo "========================================================"
