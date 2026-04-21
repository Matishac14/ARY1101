#!/bin/bash
# ==============================================================================
# Script de Validación Senior (Troubleshooting AWS ECS/ALB/RDS)
# Ejecutar localmente con AWS CLI autenticado en Learner Labs.
# ==============================================================================

# Variables de entorno (Ajusta según tu naming)
CLUSTER_NAME="cluster-nombre-apellido"
SERVICE_NAME="srv-nombre-apellido"
ALB_NAME="alb-nombre-apellido"
REGION="us-east-1"
DB_ENDPOINT="rds-nombre-apellido.csjafutlh1yz.us-east-1.rds.amazonaws.com"
DB_NAME="tienda_12345678"

echo "==========================================================="
echo "1. ESTADO DE LAS TAREAS ECS (Revisando si los contenedores mueren)"
echo "==========================================================="
# Obtener el ARN de las tareas detenidas
STOPPED_TASKS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --desired-status STOPPED --region $REGION --query 'taskArns' --output text)

if [ "$STOPPED_TASKS" != "None" ] && [ -n "$STOPPED_TASKS" ]; then
    echo ">> TAREAS DETENIDAS ENCONTRADAS. Razón de la falla:"
    # Obtener el motivo exacto por el que el contenedor "crusheo"
    aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $STOPPED_TASKS --region $REGION --query 'tasks[*].{StoppedReason:stoppedReason, ContainerStatus:containers[*].{Name:name, Reason:reason, ExitCode:exitCode}}' --output json
else
    echo ">> No hay tareas detenidas recientemente."
fi

echo -e "\n==========================================================="
echo "2. ESTADO DEL TARGET GROUP (¿ALB ve sanos a los contenedores?)"
echo "==========================================================="
# Obtener ARN del ALB
ALB_ARN=$(aws elbv2 describe-load-balancers --names $ALB_NAME --region $REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text)
# Obtener ARN del Target Group de Productos
TG_PROD_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --region $REGION --query 'TargetGroups[?contains(TargetGroupName, `prod`)].TargetGroupArn' --output text)

echo ">> Health Check del Target Group (API Productos):"
aws elbv2 describe-target-health --target-group-arn $TG_PROD_ARN --region $REGION --query 'TargetHealthDescriptions[*].{Status:TargetHealth.State, Reason:TargetHealth.Reason, Description:TargetHealth.Description}' --output table

echo -e "\n==========================================================="
echo "3. VALIDACIÓN DE LOGS DE LA APLICACIÓN (CloudWatch)"
echo "==========================================================="
echo ">> Últimos 10 eventos de error en API Productos (buscando fallos DB):"
# Buscar en los logs del contenedor de productos la palabra "error"
aws logs filter-log-events --log-group-name "/ecs/technova" --log-stream-name-prefix "prod" --filter-pattern "?error ?Error ?ERROR ?Exception ?refused" --limit 10 --region $REGION --query 'events[*].message' --output text

echo -e "\n==========================================================="
echo "4. CONEXIÓN SSH AL NODO ECS VÍA SSM (Para poblar BD si está vacía)"
echo "==========================================================="
# Obtener el ID de la instancia EC2 que forma parte del clúster ECS
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ec2-ecs-node-*" "Name=instance-state-name,Values=running" --region $REGION --query "Reservations[*].Instances[*].InstanceId" --output text)

if [ -n "$INSTANCE_ID" ]; then
    echo ">> Instancia ECS Node encontrada: $INSTANCE_ID"
    echo ">> Para conectarte y ejecutar el script SQL, ejecuta este comando manualmente:"
    echo "aws ssm start-session --target $INSTANCE_ID --region $REGION"

    echo -e "\n>> Una vez dentro de la terminal SSM, ejecuta:"
    echo "sudo su"
    echo "yum install -y git mysql"
    echo "git clone https://github.com/Matishac14/ARY1101.git"
    echo "cd ARY1101"
    echo "mysql -h $DB_ENDPOINT -u admin -pAdmin12345! $DB_NAME < init.sql"
else
    echo ">> ERROR: No se encontró instancia EC2 corriendo para el clúster."
fi