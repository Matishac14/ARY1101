#!/bin/bash
# ==============================================================================
# SCRIPT 2: POST-DEPLOY (INYECCIÓN RDS VÍA SSM)
# ==============================================================================
REGION="us-east-1"
ALUMNO="matias-fernandez"

echo ">> 1. Obteniendo datos dinámicos de Terraform..."
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
ALB_URL=$(terraform output -raw alb_dns_name)
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ec2-ecs-node-$ALUMNO" "Name=instance-state-name,Values=running" --region $REGION --query "Reservations[0].Instances[0].InstanceId" --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ Error: Aún no hay EC2 activos. Terraform acaba de terminar. Espera 60 segundos y vuelve a ejecutar este script."
    exit 1
fi

echo ">> 2. Inyectando BD en $RDS_ENDPOINT a través de $INSTANCE_ID..."
aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --targets "Key=InstanceIds,Values=$INSTANCE_ID" \
    --parameters 'commands=["mysql -h '$RDS_ENDPOINT' -u admin -p20099194k -e \"USE tienda_12345678; CREATE TABLE IF NOT EXISTS productos (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(255) NOT NULL, precio DECIMAL(10,2) NOT NULL, stock INT NOT NULL DEFAULT 0, categoria VARCHAR(100)); CREATE TABLE IF NOT EXISTS pedidos (id INT AUTO_INCREMENT PRIMARY KEY, producto_id INT NOT NULL, cantidad INT NOT NULL, estado ENUM('\"'pendiente'\"','\"'procesado'\"','\"'enviado'\"','\"'cancelado'\"') NOT NULL DEFAULT '\"'pendiente'\"', FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT); INSERT IGNORE INTO productos (id, nombre, precio, stock, categoria) VALUES (1, '\"'Notebook ASUS'\"', 649990, 10, '\"'Computadores'\"'); ALTER USER '\"'admin'\"'@'\"'%'\"' IDENTIFIED WITH mysql_native_password BY '\"'20099194k'\"'; FLUSH PRIVILEGES;\""]' \
    --region $REGION > /dev/null

echo ">> 3. Forzando reinicio de contenedores para leer la nueva base de datos..."
aws ecs update-service --cluster cluster-$ALUMNO --service srv-$ALUMNO --force-new-deployment --region $REGION > /dev/null

echo "====================================================="
echo "✅ OPERACIÓN FINALIZADA."
echo "Espera 60 segundos y entra a tu aplicación aquí:"
echo "$ALB_URL"
echo "====================================================="