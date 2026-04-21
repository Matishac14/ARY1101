# ------------------------------------------------------------------------------
# 0. CONFIGURACIÓN BASE Y RESTRICCIONES LEARNER LABS
# ------------------------------------------------------------------------------
provider "aws" {
  region = "us-east-1"
}

variable "alumno" {
  description = "Sufijo para naming convention"
  default     = "nombre-apellido"
}

variable "rut_db" {
  description = "Dígitos del RUT para nombre de BD"
  default     = "12345678"
}

# Obtener cuenta actual para URLs de ECR
data "aws_caller_identity" "current" {}

# Obtener los roles preexistentes obligatorios del Lab
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}

# ------------------------------------------------------------------------------
# 1. REDES (Segmentación estricta)
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

# Subredes Públicas (ALB, NAT GW)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24" # Rango ajustado para caber en /22
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-pub-1a-${var.alumno}" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24" # Rango ajustado para caber en /22
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-pub-1b-${var.alumno}" }
}

# Subred Privada (ECS, RDS, EFS)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24" # Rango ajustado para caber en /22
  availability_zone = "us-east-1a"
  tags              = { Name = "subnet-priv-1a-${var.alumno}" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24" # Rango ajustado para caber en /22
  availability_zone = "us-east-1b"
  tags              = { Name = "subnet-priv-1b-${var.alumno}" }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "nat-${var.alumno}" }
}

# Tablas de Ruteo y Asociaciones
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
# 2. SEGURIDAD (Zero Trust Security Groups)
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "alb-${var.alumno}-sg"
  vpc_id      = aws_vpc.main.id
  description = "Punto de entrada publico (Capa 7)"

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
  description = "Compute Node. Solo recibe trafico del ALB. SIN PUERTO 22 (SSH)"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 3002
    to_port         = 3002
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
  description = "BD. Aislamiento estricto."

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_security_group" "efs" {
  name        = "efs-${var.alumno}-sg"
  vpc_id      = aws_vpc.main.id
  description = "Almacenamiento persistente NFS"

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# 3. AWS WAF (Seguridad Perimetral Web)
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "main" {
  name        = "waf-${var.alumno}"
  description = "Proteccion contra OWASP Top 10"
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
# 4. PERSISTENCIA DE DATOS (RDS + EFS)
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
  db_name                = "tienda_${var.rut_db}"
  username               = "admin"
  password               = "Admin12345!"
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  skip_final_snapshot    = true
}

resource "aws_secretsmanager_secret" "db_creds" {
  name = "technova/db-${var.alumno}-2"
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    ALUMNO_NOMBRE  = "TuNombre"
    ALUMNO_RUT     = "12345678-9"
    ALUMNO_SECCION = "ARY1101"
    DB_HOST        = aws_db_instance.mysql.endpoint
    DB_NAME        = "tienda_${var.rut_db}"
    DB_USER        = "admin"
    DB_PASS        = "Admin12345!"
  })
}

resource "aws_efs_file_system" "shared" {
  creation_token = "efs-${var.alumno}"
  encrypted      = true
  tags           = { Name = "efs-${var.alumno}" }
}

resource "aws_efs_mount_target" "shared_a" {
  file_system_id  = aws_efs_file_system.shared.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs.id]
}

# ------------------------------------------------------------------------------
# 5. BALANCEADOR DE CARGA (ALB + Target Groups)
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
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/api/productos/info"
  }
}

resource "aws_lb_target_group" "api_ped" {
  name     = "tg-ped-${var.alumno}"
  port     = 3002
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/api/pedidos/info"
  }
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
# 6. ORQUESTACIÓN (ECS Launch Type EC2)
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "cluster-${var.alumno}"
}

# Data source para obtener la AMI de ECS optimizada más reciente dinámicamente
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# Plantilla Inmutable para el Auto Scaling Group (EC2 Node)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/technova"
  retention_in_days = 1 # Ahorro de costos
}

resource "aws_launch_template" "ecs_node" {
  name_prefix   = "ecs-node-${var.alumno}"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value # AMI dinámica
  instance_type = "t3.small"

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs.id]

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF
  )
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "asg-ecs-${var.alumno}"
  vpc_zone_identifier = [aws_subnet.private_a.id]
  desired_capacity    = 1
  max_size            = 1
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
      portMappings = [{ containerPort = 80, hostPort = 80, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options   = { "awslogs-group" = "/ecs/technova", "awslogs-region" = "us-east-1", "awslogs-stream-prefix" = "front" }
      }
    },
    {
      name         = "api-productos"
      image        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/technova-api-productos:latest"
      cpu          = 256
      memory       = 256
      essential    = true
      portMappings = [{ containerPort = 3001, hostPort = 3001, protocol = "tcp" }]
      secrets = [
        { name = "DB_HOST", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_HOST::" },
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_USER::" },
        { name = "DB_PASS", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_PASS::" },
        { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_NAME::" },
        { name = "ALUMNO_NOMBRE", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:ALUMNO_NOMBRE::" },
        { name = "ALUMNO_RUT", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:ALUMNO_RUT::" },
        { name = "ALUMNO_SECCION", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:ALUMNO_SECCION::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = { "awslogs-group" = "/ecs/technova", "awslogs-region" = "us-east-1", "awslogs-stream-prefix" = "prod" }
      }
    },
    {
      name         = "api-pedidos"
      image        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/technova-api-pedidos:latest"
      cpu          = 256
      memory       = 256
      essential    = true
      portMappings = [{ containerPort = 3002, hostPort = 3002, protocol = "tcp" }]
      secrets = [
        { name = "DB_HOST", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_HOST::" },
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_USER::" },
        { name = "DB_PASS", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_PASS::" },
        { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db_creds.arn}:DB_NAME::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = { "awslogs-group" = "/ecs/technova", "awslogs-region" = "us-east-1", "awslogs-stream-prefix" = "ped" }
      }
    }
  ])
}

resource "aws_ecs_service" "app_service" {
  name            = "srv-${var.alumno}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "EC2"
}

resource "aws_s3_bucket" "frontend_fase2" {
  bucket = "frontend-fase2-${var.alumno}-${var.rut_db}"
}

resource "aws_s3_bucket_website_configuration" "frontend_fase2" {
  bucket = aws_s3_bucket.frontend_fase2.id
  index_document {
    suffix = "index.html"
  }
}