#!/bin/bash
# ==============================================================================
# SCRIPT 03 — Validación completa de la POC TechNova
# ARY1101 · Matias Fernandez
# Uso: ./03_validate.sh
# Valida: EC2, containers, RDS, ALB endpoints, S3 frontend
# ==============================================================================
set -euo pipefail

REGION="us-east-1"
PASS=0; FAIL=0

check() {
  local desc="$1"; local cmd="$2"; local expect="$3"
  local result
  result=$(eval "$cmd" 2>/dev/null || echo "ERROR")
  if echo "$result" | grep -q "$expect"; then
    echo "  ✅ $desc"
    ((PASS++))
  else
    echo "  ❌ $desc → '$result'"
    ((FAIL++))
  fi
}

echo "========================================================"
echo " TechNova POC — Validación Completa"
echo "========================================================"

echo ""
echo ">> [1/6] Leyendo outputs Terraform..."
ALB_URL=$(terraform output -raw alb_dns_name)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
INSTANCE_ID=$(terraform output -raw ec2_instance_id)
S3_URL=$(terraform output -raw s3_website_url)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

echo "   ALB:    $ALB_URL"
echo "   RDS:    $RDS_ENDPOINT"
echo "   EC2:    $INSTANCE_ID"
echo "   S3:     $S3_URL"

echo ""
echo ">> [2/6] Estado EC2..."
check "EC2 running" \
  "aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text" \
  "running"

check "SSM Agent online" \
  "aws ssm describe-instance-information --filters 'Key=InstanceIds,Values=$INSTANCE_ID' --region $REGION --query 'InstanceInformationList[0].PingStatus' --output text" \
  "Online"

echo ""
echo ">> [3/6] Containers Docker en EC2 (via SSM)..."
CMD_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=InstanceIds,Values=$INSTANCE_ID" \
  --parameters "commands=[\"docker ps --format '{{.Names}} {{.Status}}'\"]" \
  --region "$REGION" \
  --query "Command.CommandId" --output text)
sleep 8
DOCKER_OUT=$(aws ssm get-command-invocation \
  --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
  --region "$REGION" --query "StandardOutputContent" --output text)

echo "$DOCKER_OUT"
echo "$DOCKER_OUT" | grep -q "technova-api-productos" && \
  { echo "  ✅ Container api-productos corriendo"; ((PASS++)); } || \
  { echo "  ❌ Container api-productos NO encontrado"; ((FAIL++)); }
echo "$DOCKER_OUT" | grep -q "technova-api-pedidos" && \
  { echo "  ✅ Container api-pedidos corriendo"; ((PASS++)); } || \
  { echo "  ❌ Container api-pedidos NO encontrado"; ((FAIL++)); }

echo ""
echo ">> [4/6] RDS disponible..."
check "RDS status available" \
  "aws rds describe-db-instances --db-instance-identifier rds-matias-fernandez --region $REGION --query 'DBInstances[0].DBInstanceStatus' --output text" \
  "available"

echo ""
echo ">> [5/6] ALB endpoints (espera ~30s si recién levantó)..."
for EP in "/api/productos/info" "/api/pedidos/info"; do
  echo "  GET $ALB_URL$EP"
  RESP=$(curl -sf --max-time 20 "$ALB_URL$EP" 2>/dev/null || echo "")
  if [ -n "$RESP" ]; then
    echo "  ✅ Respuesta: $RESP"
    ((PASS++))
  else
    echo "  ❌ Sin respuesta en $EP"
    ((FAIL++))
  fi
done

echo ""
echo ">> [6/6] Frontend S3..."
S3_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$S3_URL" 2>/dev/null || echo "000")
if [ "$S3_CODE" = "200" ]; then
  echo "  ✅ Frontend S3 responde HTTP 200"
  ((PASS++))
else
  echo "  ❌ Frontend S3 → HTTP $S3_CODE (espera 1 min si recién creado)"
  ((FAIL++))
fi

echo ""
echo "========================================================"
echo " RESUMEN: $PASS pasaron | $FAIL fallaron"
if [ "$FAIL" -eq 0 ]; then
  echo " ✅ POC COMPLETAMENTE FUNCIONAL"
else
  echo " ⚠️  Revisar los items fallidos antes de la evaluación"
fi
echo "========================================================"
