# ==============================================================================
# TECNOVA - MAIN.TF
# Autor: Matias Fernandez / ARY1101
# Arquitectura: S3 Static Website (frontend) + ALB + EC2 (APIs Node.js) + RDS MySQL
#
# RESTRICCIONES LEARNER LAB APLICADAS:
#   - Sin crear/modificar roles IAM → usa LabRole / LabInstanceProfile existentes
#   - Sin Enhanced Monitoring en RDS (monitoring_interval = 0)
#   - Sin PIOPS storage → gp2
#   - Sin WAFv2 / Secrets Manager (no requeridos por rúbrica)
#   - Max 9 EC2 simultáneos → solo 1 EC2 para APIs
#   - Solo us-east-1
#   - S3 bucket con public access para frontend estático
#   - CORS habilitado en APIs para permitir llamadas desde S3
# ==============================================================================

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# LabRole y LabInstanceProfile pre-creados (Learner Lab no permite crear roles IAM)
data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}

# AMI Amazon Linux 2 (última versión via SSM Parameter Store)
data "aws_ssm_parameter" "al2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# ==============================================================================
# 1. RED — VPC + Subredes + Routing
# Topología: 1 AZ funcional (1a) + 1 AZ declarada (1b) requerida por ALB y RDS
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "vpc-${var.alumno}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-${var.alumno}" }
}

# Subred pública 1a → ALB + NAT Gateway
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = { Name = "subnet-pub-1a-${var.alumno}" }
}

# Subred pública 1b → requerida por ALB (mínimo 2 AZs) y RDS subnet group
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = { Name = "subnet-pub-1b-${var.alumno}" }
}

# Subred privada 1a → EC2 (APIs) + RDS
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "subnet-priv-1a-${var.alumno}" }
}

# Subred privada 1b → requerida por RDS subnet group
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "subnet-priv-1b-${var.alumno}" }
}

# NAT Gateway → permite al EC2 privado hacer pull desde ECR / internet
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "nat-${var.alumno}" }
  depends_on    = [aws_internet_gateway.igw]
}

# Tabla de rutas pública → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "rt-public-${var.alumno}" }
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Tabla de rutas privada → NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "rt-private-${var.alumno}" }
}

resource "aws_route_table_association" "priv_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "priv_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# 2. SECURITY GROUPS — 3 capas, principio de mínimo privilegio
#    sg-alb  → acepta tráfico HTTP público
#    sg-ec2  → acepta tráfico SOLO desde sg-alb (puertos 3001 y 3002)
#    sg-rds  → acepta MySQL SOLO desde sg-ec2
#
# NOTA EVALUACIÓN: RDS abierto a 0.0.0.0/0 = criterio seguridad en 0
# ==============================================================================

resource "aws_security_group" "alb" {
  name        = "alb-${var.alumno}-sg"
  description = "ALB: HTTP publico desde internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP publico"
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

  tags = { Name = "alb-sg-${var.alumno}" }
}

resource "aws_security_group" "ec2" {
  name        = "ec2-sg-${var.alumno}"
  description = "EC2 APIs: solo desde ALB (puertos 3001 y 3002)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API Productos desde ALB"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "API Pedidos desde ALB"
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

  tags = { Name = "ec2-sg-${var.alumno}" }
}

resource "aws_security_group" "rds" {
  name        = "rds-sg-${var.alumno}"
  description = "RDS MySQL solo desde ec2-sg - nunca desde internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL desde EC2 unicamente"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = { Name = "rds-sg-${var.alumno}" }
}

# ==============================================================================
# 3. RDS MySQL — subred privada, sin Enhanced Monitoring (Learner Lab)
# ==============================================================================

resource "aws_db_subnet_group" "rds" {
  name       = "rds-sng-${var.alumno}"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "rds-sng-${var.alumno}" }
}

resource "aws_db_instance" "mysql" {
  identifier        = "rds-${var.alumno}"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name

  # Learner Lab: Enhanced Monitoring no soportado → monitoring_interval = 0
  monitoring_interval = 0

  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "rds-${var.alumno}" }
}

# ==============================================================================
# 4. EC2 — subred privada, solo APIs (ya no sirve frontend)
#    user_data: instala Docker, mysql client y configura el ambiente
#    LabInstanceProfile: permite SSM Session Manager sin SSH ni puerto 22
# ==============================================================================

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2_ami.value
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # Docker Compose
    curl -fsSL \
      "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # MySQL client para inyectar init.sql via SSM desde local
    yum install -y mysql

    mkdir -p /home/ec2-user/technova
    chown ec2-user:ec2-user /home/ec2-user/technova

    echo "USERDATA_OK" > /tmp/userdata_status
  EOF
  )

  tags = { Name = "ec2-${var.alumno}" }

  depends_on = [aws_nat_gateway.nat]
}

# ==============================================================================
# 5. ALB — SOLO 2 Target Groups para APIs (frontend ya está en S3)
#    Justificación: el frontend es contenido estático → S3 es más adecuado
#    El ALB expone únicamente las APIs con lógica de negocio
# ==============================================================================

resource "aws_lb" "main" {
  name               = "alb-${var.alumno}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = { Name = "alb-${var.alumno}" }
}

# Target Group API Productos → EC2:3001
resource "aws_lb_target_group" "api_productos" {
  name        = "tg-productos-${var.alumno}"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/api/productos/info"
    port                = "3001"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "tg-productos-${var.alumno}" }
}

# Target Group API Pedidos → EC2:3002
resource "aws_lb_target_group" "api_pedidos" {
  name        = "tg-pedidos-${var.alumno}"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/api/pedidos/info"
    port                = "3002"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "tg-pedidos-${var.alumno}" }
}

# Registro del EC2 en ambos Target Groups con puertos distintos
resource "aws_lb_target_group_attachment" "api_productos" {
  target_group_arn = aws_lb_target_group.api_productos.arn
  target_id        = aws_instance.app.id
  port             = 3001
}

resource "aws_lb_target_group_attachment" "api_pedidos" {
  target_group_arn = aws_lb_target_group.api_pedidos.arn
  target_id        = aws_instance.app.id
  port             = 3002
}

# Listener HTTP:80
# Default → 404 (sin frontend en ALB, el tráfico / va directo a S3)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "TechNova API Gateway - use /api/productos o /api/pedidos"
      status_code  = "200"
    }
  }
}

# Regla 1: /api/productos* → tg-productos
resource "aws_lb_listener_rule" "api_productos" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/productos*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_productos.arn
  }
}

# Regla 2: /api/pedidos* → tg-pedidos
resource "aws_lb_listener_rule" "api_pedidos" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  condition {
    path_pattern {
      values = ["/api/pedidos*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_pedidos.arn
  }
}

# ==============================================================================
# 6. S3 STATIC WEBSITE — Frontend estático de TechNova
#    Justificación arquitectural:
#    - El frontend es HTML/JS/CSS puro servido por Nginx → objeto estático
#    - S3 Static Website elimina el proceso de servidor para contenido estático
#    - Reduce carga del EC2 (solo corre las 2 APIs con lógica de negocio)
#    - Costo menor: S3 cobra por almacenamiento/requests vs EC2 por hora
#    - Práctica estándar de la industria para SPA y sitios estáticos
#    - El JS del frontend apunta al ALB para consumir las APIs
# ==============================================================================

resource "aws_s3_bucket" "frontend" {
  bucket        = "technova-frontend-${var.alumno}-${var.s3_bucket_suffix}"
  force_destroy = true
  tags          = { Name = "s3-frontend-${var.alumno}" }
}

# Deshabilitar bloqueo de acceso público (requerido para Static Website)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Política pública de lectura para el sitio web
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# Habilitar S3 Static Website Hosting
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# CORS en S3: permite que el browser del usuario haga requests cross-origin al ALB
# Nota: el CORS crítico es en las APIs Node.js (Access-Control-Allow-Origin)
# Este CORS de S3 permite que otros orígenes descarguen assets del bucket
resource "aws_s3_bucket_cors_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
