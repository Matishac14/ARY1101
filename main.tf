# ==============================================================================
# TECNOVA - ARQUITECTURA CLOUD NATIVE (AWS WELL-ARCHITECTED)
# Autor: Matias Fernandez / Estudiante Ing. Plataformas
# Topología: Multi-AZ (Alta Disponibilidad), Zero-Trust, Serverless-ready.
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. CONFIGURACIÓN BASE
# ------------------------------------------------------------------------------
provider "aws" {
  region = "us-east-1"
}

variable "alumno" {
  description = "Sufijo para naming convention"
  default     = "matias-fernandez"
}

variable "rut_db" {
  description = "Dígitos del RUT para nombre de BD"
  default     = "12345678"
}

data "aws_caller_identity" "current" {}
data "aws_iam_role" "lab_role" { name = "LabRole" }
data "aws_iam_instance_profile" "lab_profile" { name = "LabInstanceProfile" }

# ------------------------------------------------------------------------------
# 1. REDES (Multi-AZ)
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-${var.alumno}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${var.alumno}" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-pub-1a-${var.alumno}" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-pub-1b-${var.alumno}" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "subnet-priv-1a-${var.alumno}" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "subnet-priv-1b-${var.alumno}" }
}

resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "nat-${var.alumno}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "priv_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "priv_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------------------
# 2. FIREWALLS ZERO-TRUST
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "alb-${var.alumno}-sg"
  vpc_id      = aws_vpc.main.id
  description = "Capa 7: Entrada publica HTTP"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name        = "ecs-${var.alumno}-sg"
  vpc_id      = aws_vpc.main.id
  description = "Compute Node: Trafico desde ALB"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 3001
    to_port         = 3002
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "rds-${var.alumno}-sg"
  vpc_id      = aws_vpc.main.id
  description = "BD: Aislamiento estricto"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

# ------------------------------------------------------------------------------
# 3. WAF
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "main" {
  name        = "waf-${var.alumno}"
  description = "Proteccion OWASP"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-metric"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
      sampled_requests_enabled   = true
    }
  }
}

# ------------------------------------------------------------------------------
# 4. CAPA DE DATOS (RDS + SECRETS MANAGER)
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "rds" {
  name       = "rds-sng-${var.alumno}"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_db_instance" "mysql" {
  identifier             = "rds-${var.alumno}"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "technova"
  username               = "admin"
  password               = "20099194k"
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  skip_final_snapshot    = true
}

resource "aws_secretsmanager_secret" "db_creds" {
  name = "technova/db-${var.alumno}-v7" # Iteración segura
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    ALUMNO_NOMBRE  = "Matias Fernandez"
    ALUMNO_RUT     = "20099194-k"
    ALUMNO_SECCION = "ARY1101"
    DB_HOST        = aws_db_instance.mysql.address
    DB_NAME        = "technova"
    DB_USER        = "admin"
    DB_PASSWORD    = "20099194k" # Coincide con el código Node.js
  })
}

# ------------------------------------------------------------------------------
# 5. BALANCEADOR DE CARGA (ALB)
# ------------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "alb-${var.alumno}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_wafv2_web_acl_association" "waf_alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

resource "aws_lb_target_group" "frontend" {
  name     = "tg-front-${var.alumno}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group" "api_prod" {
  name     = "tg-prod-${var.alumno}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check { path = "/api/productos/info" }
}

resource "aws_lb_target_group" "api_ped" {
  name     = "tg-ped-${var.alumno}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check { path = "/api/pedidos/info" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api_prod" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  condition {
    path_pattern {
      values = ["/api/productos*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_prod.arn
  }
}

resource "aws_lb_listener_rule" "api_ped" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  condition {
    path_pattern {
      values = ["/api/pedidos*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_ped.arn
  }
}

# ------------------------------------------------------------------------------
# 6. CLÚSTER ECS Y AUTO SCALING
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "cluster-${var.alumno}"
}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/technova"
  retention_in_days = 1
}

resource "aws_launch_template" "ecs_node" {
  name_prefix   = "ecs-node-${var.alumno}"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = "t3.small"
  iam_instance_profile { name = data.aws_iam_instance_profile.lab_profile.name }
  vpc_security_group_ids = [aws_security_group.ecs.id]
  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF
  )
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "asg-ecs-${var.alumno}"
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1

  launch_template {
    id      = aws_launch_template.ecs_node.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ec2-ecs-node-${var.alumno}"
    propagate_at_launch = true
  }
}

# ------------------------------------------------------------------------------
# 7. ORQUESTACIÓN: TAREAS (Zero Downtime)
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "task-${var.alumno}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name         = "frontend"
      image        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/technova-frontend:latest"
      cpu          = 256
      memory       = 512
      essential    = true
      portMappings = [{ containerPort = 80, hostPort = 0, protocol = "tcp" }]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = "/ecs/technova", "awslogs-region" = "us-east-1", "awslogs-stream-prefix" = "front" } }
    },
    {
      name         = "api-productos"
      image        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/technova-api-productos:latest"
      cpu          = 256
      memory       = 256
      essential    = true
      portMappings = [{ containerPort = 3001, hostPort = 0, protocol = "tcp" }]
      secrets = [
        { name = "DB_HOST", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_HOST::" },
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_USER::" },
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_PASSWORD::" },
        { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_NAME::" },
        { name = "ALUMNO_NOMBRE", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:ALUMNO_NOMBRE::" },
        { name = "ALUMNO_RUT", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:ALUMNO_RUT::" },
        { name = "ALUMNO_SECCION", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:ALUMNO_SECCION::" }
      ]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = "/ecs/technova", "awslogs-region" = "us-east-1", "awslogs-stream-prefix" = "prod" } }
    },
    {
      name         = "api-pedidos"
      image        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/technova-api-pedidos:latest"
      cpu          = 256
      memory       = 256
      essential    = true
      portMappings = [{ containerPort = 3002, hostPort = 0, protocol = "tcp" }]
      secrets = [
        { name = "DB_HOST", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_HOST::" },
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_USER::" },
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_PASSWORD::" },
        { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_NAME::" }
      ]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = "/ecs/technova", "awslogs-region" = "us-east-1", "awslogs-stream-prefix" = "ped" } }
    }
  ])
}

resource "aws_ecs_service" "app_service" {
  name            = "srv-${var.alumno}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "EC2"

  depends_on = [
    aws_lb_listener_rule.api_prod,
    aws_lb_listener_rule.api_ped,
    aws_lb_listener.http
  ]

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_prod.arn
    container_name   = "api-productos"
    container_port   = 3001
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_ped.arn
    container_name   = "api-pedidos"
    container_port   = 3002
  }
}

# ------------------------------------------------------------------------------
# 8. OUTPUTS (Para consumo de scripts y validación)
# ------------------------------------------------------------------------------
output "rds_endpoint" {
  description = "Endpoint privado de MySQL para inyeccion via SSM"
  value       = aws_db_instance.mysql.address
}

output "alb_dns_name" {
  description = "URL publica del Balanceador de Carga"
  value       = "http://${aws_lb.main.dns_name}"
}