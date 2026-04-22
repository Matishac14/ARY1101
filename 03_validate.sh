#!/bin/bash
# ==============================================================================
# SCRIPT 3: VALIDACIÓN TOTAL (ALB + RDS)
# ==============================================================================
REGION="us-east-1"
ALUMNO="matias-fernandez"

echo ">> 1. Extrayendo variables de Terraform..."
ALB_URL=$(terraform output -raw alb_dns_name)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ec2-ecs-node-$ALUMNO" "Name=instance-state-name,Values=running" --region $REGION --query "Reservations[0].Instances[0].InstanceId" --output text)

echo "====================================================="
echo ">> 2. VALIDANDO BALANCEADOR DE CARGA Y API (CAPA 7)"
echo "====================================================="
echo "Haciendo petición GET a: $ALB_URL/api/productos/info"

# Manejo de error graceful para la dependencia 'jq'
if command -v jq &> /dev/null; then
    curl -s "$ALB_URL/api/productos/info" | jq
else
    echo "⚠️  [Advertencia]: 'jq' no está instalado. Mostrando salida JSON en crudo:"
    curl -s "$ALB_URL/api/productos/info"
    echo -e "\n(Tip: Instala jq con 'brew install jq' en tu Mac)"
fi
echo ""

echo "====================================================="
echo ">> 3. VALIDANDO POBLAMIENTO EN RDS (CAPA DATOS)"
echo "====================================================="
echo "Enviando consulta SQL vía SSM a través del EC2: $INSTANCE_ID..."

# Enviamos un comando que hace un SHOW TABLES y un SELECT a la tabla productos
aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --targets "Key=InstanceIds,Values=$INSTANCE_ID" \
    --parameters 'commands=["mysql -h '$RDS_ENDPOINT' -u admin -p20099194k -D tienda_12345678 -t -e \"SHOW TABLES; SELECT id, nombre, precio, stock FROM productos;\""]' \
    --region $REGION \
    --query "Command.CommandId" \
    --output text > cmd_id.txt

CMD_ID=$(cat cmd_id.txt)
echo "Esperando respuesta de RDS (5 segundos)..."
sleep 5

aws ssm get-command-invocation \
    --command-id "$CMD_ID" \
    --instance-id "$INSTANCE_ID" \
    --region $REGION \
    --query "StandardOutputContent" \
    --output text

rm cmd_id.txt
echo "====================================================="
echo "✅ VALIDACIÓN FINALIZADA."