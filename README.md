# ARY1101 – Infraestructura Cloud II

Repositorio de la asignatura **ARY1101 – Infraestructura Cloud II**. Contiene la infraestructura como código (Terraform), scripts de despliegue y el código fuente de la aplicación **TechNova**, compuesta por múltiples microservicios.

## Estructura del repositorio

```
.
├── main.tf                    # Infraestructura principal en Terraform
├── variables.tf               # Variables de Terraform
├── outputs.tf                 # Outputs de Terraform
├── docker-compose.yml         # Orquestación local de contenedores
├── .env.example               # Variables de entorno de ejemplo
├── 01_build_push.sh           # Script: build y push de imágenes Docker
├── 02_deploy_app.sh           # Script: despliegue de la aplicación en AWS
├── 02_inject_db.sh            # Script: inyección de datos en base de datos
├── 03_validate.sh             # Script: validación del despliegue
├── technova-api-pedidos/      # Microservicio: API de pedidos
├── technova-api-productos/    # Microservicio: API de productos
├── technova-db/               # Configuración de base de datos
└── technova-frontend/         # Frontend de la aplicación
```

## Requisitos

- Terraform >= 1.x
- AWS CLI configurado con credenciales válidas
- Docker y Docker Compose
- Bash (para los scripts de despliegue)

## Uso

### Infraestructura (Terraform)

```bash
terraform init
terraform plan
terraform apply
```

### Ejecución local con Docker Compose

```bash
# Copiar variables de entorno
cp .env.example .env
# Editar .env con tus valores

# Levantar todos los servicios
docker-compose up -d
```

### Despliegue en AWS (orden de ejecución)

```bash
bash 01_build_push.sh    # Build y push de imágenes a ECR
bash 02_deploy_app.sh    # Despliegue en EKS/ECS
bash 02_inject_db.sh     # Carga inicial de datos
bash 03_validate.sh      # Validación del entorno
```

> ⚠️ Configurar las variables de entorno en `.env` antes de ejecutar cualquier script.
