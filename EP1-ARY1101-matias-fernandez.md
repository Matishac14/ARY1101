# TechNova Solutions — Migración a AWS
## Proof of Concept · Presentación al Directorio

**Alumno:** Matias Fernandez | **RUT:** 20.099.194-k | **Sección:** ARY1101 | **Fecha:** Abril 2026 | **Plataforma:** AWS Learner Labs · us-east-1

---

## Slide 01 — Portada

**TechNova Solutions — Migración a AWS**

Consultor externo contratado para responder: *¿Puede TechNova migrar a la nube de forma viable?*  
Esta presentación responde esa pregunta con evidencia técnica y análisis de negocio.

---

## Slide 02 — Resumen Ejecutivo

La POC demuestra que TechNova **puede migrar a AWS de forma viable, técnica y económicamente**. La arquitectura propuesta elimina el punto de falla único que provocó 14 horas de downtime el último año, separa el frontend estático de las APIs con lógica de negocio, y opera a un costo estimado inferior al datacenter arrendado actual.

**Recomendación:** Migrar. La viabilidad técnica está demostrada. El siguiente paso es una migración progresiva en 3 fases.

---

## Slide 03 — El Problema de Negocio

### Impacto de las caídas on-premise

| Métrica | Valor |
|---|---|
| Eventos de caída (último año) | 9 |
| Tiempo total caído | 14 horas |
| Duración promedio por evento | ~93 minutos |
| Impacto por hora de downtime | 3% de ventas diarias |
| Causa raíz | VMware en datacenter sin redundancia |
| Equipo de mantención | 2 personas — gestión manual |

**Problema real:** Los peaks de demanda (Black Friday, Cyber Monday) saturan servidores que no escalan. Cada caída genera pérdidas no recuperables. El equipo dedica tiempo a apagar incendios en lugar de agregar valor al negocio.

**¿Por qué actuar ahora?** El crecimiento del 60% en ventas en 18 meses hace que el riesgo de caída sea mayor cada mes que pasa.

---

## Slide 04 — Viabilidad y Costos

### Estimación mensual AWS (Pricing Calculator · us-east-1)

| Componente | Servicio AWS | Costo est. mensual |
|---|---|---|
| Cómputo APIs | EC2 t3.micro (On-Demand, 24/7) | ~$8.50 |
| Base de datos | RDS MySQL db.t3.micro | ~$14.00 |
| Balanceador de carga | ALB (~100 GB/mes) | ~$18.00 |
| Frontend estático | S3 Static Website (~5 GB) | ~$0.50 |
| Red de salida | NAT Gateway + transferencia | ~$10.00 |
| Registro Docker | ECR (2 repos, ~500 MB) | ~$0.05 |
| **Total estimado** | | **~$51 USD/mes** |

> Comparación clave: 1 hora de downtime = 3% de ventas diarias. Con ~$51/mes se elimina ese riesgo estructuralmente. Una migración a producción con alta disponibilidad alcanza ~$120–180 USD/mes, aún inferior al costo de un datacenter arrendado con personal dedicado.

---

## Slide 05 — Recomendación y Próximos Pasos

### Decisión recomendada: **Migrar a AWS en 3 fases**

| Fase | Descripción | Timeline |
|---|---|---|
| **Fase 1 — POC** *(completada)* | Arquitectura base funcional. Valida viabilidad técnica y económica | Semana 1–2 |
| **Fase 2 — Staging** | Cuenta AWS productiva, dominio propio + HTTPS (ACM), CI/CD básico | Mes 1–2 |
| **Fase 3 — Producción** | Auto Scaling, CloudFront CDN, RDS Multi-AZ, CloudWatch, Backups automáticos | Mes 3–4 |

**Posición del consultor:** Los datos son concluyentes. La POC está corriendo. No migrar representa un riesgo operacional creciente conforme el e-commerce escala. La inversión en AWS se amortiza con evitar un solo evento de caída.

---

## Slide 06 — Arquitectura TO-BE

### Diagrama de la solución propuesta

```
INTERNET
    │
    ├──► S3 Static Website ────────────────────► HTML / JS / CSS
    │    technova-frontend-matias-fernandez       (contenido estático)
    │    Justificación: sin proceso de servidor,
    │    costo mínimo, escala automático
    │
    └──► ALB (Application Load Balancer)
         alb-matias-fernandez
             │
             ├── /api/productos* ──► tg-productos-matias-fernandez
             │                             │
             └── /api/pedidos*  ──► tg-pedidos-matias-fernandez
                                           │
                                    EC2 t3.micro (subred privada)
                                    ec2-matias-fernandez
                                    ├── api-productos :3001
                                    └── api-pedidos   :3002
                                           │
                                    RDS MySQL 8.0 (subred privada)
                                    rds-matias-fernandez · db.t3.micro
                                    :3306 — solo desde sg-ec2
```

### Por qué S3 para el frontend

El frontend es HTML/JS/CSS puro — contenido completamente estático. S3 Static Website elimina la necesidad de Nginx como proceso de servidor, reduce la carga del EC2 (que se concentra exclusivamente en las APIs con lógica de negocio), disminuye el costo y es la práctica estándar de la industria para contenido estático. El JavaScript del frontend hace `fetch()` al ALB para consumir las APIs dinámicas.

---

## Slide 07 — Red y Seguridad

### VPC y Segmentación de Red

| Recurso | Nombre | Detalle |
|---|---|---|
| VPC | vpc-matias-fernandez | 10.0.0.0/22 |
| Subred pública 1a | subnet-pub-1a-matias-fernandez | 10.0.0.0/24 · ALB + NAT GW |
| Subred pública 1b | subnet-pub-1b-matias-fernandez | 10.0.1.0/24 · ALB (2da AZ requerida) |
| Subred privada 1a | subnet-priv-1a-matias-fernandez | 10.0.2.0/24 · EC2 + RDS |
| Subred privada 1b | subnet-priv-1b-matias-fernandez | 10.0.3.0/24 · RDS subnet group |
| Internet Gateway | igw-matias-fernandez | Entrada pública al VPC |
| NAT Gateway | nat-matias-fernandez | Salida controlada EC2 privado |

### Security Groups — 3 capas, principio de mínimo privilegio

**sg-alb-matias-fernandez**
- INGRESS: TCP :80 desde 0.0.0.0/0

**sg-ec2-matias-fernandez**
- INGRESS: TCP :3001 desde sg-alb únicamente
- INGRESS: TCP :3002 desde sg-alb únicamente
- El EC2 nunca está expuesto directamente a internet

**sg-rds-matias-fernandez**
- INGRESS: TCP :3306 desde sg-ec2 únicamente
- La base de datos es invisible desde internet

> **Captura requerida:** VPC console mostrando las 4 subredes + IGW + tablas de ruta. Security Groups con reglas de ingress correctas.

---

## Slide 08 — EC2 y RDS

### EC2 — Servidor de APIs

| Atributo | Valor |
|---|---|
| Nombre | ec2-matias-fernandez |
| AMI | Amazon Linux 2 (última versión via SSM Parameter) |
| Tipo | t3.micro |
| Subred | subnet-priv-1a (privada, sin IP pública) |
| IAM Profile | LabInstanceProfile |
| Acceso operacional | SSM Session Manager — sin puerto 22 abierto |
| Software | Docker + docker-compose + mysql client (user_data) |

### RDS — Base de Datos MySQL

| Atributo | Valor |
|---|---|
| Identificador | rds-matias-fernandez |
| Motor | MySQL 8.0 |
| Instancia | db.t3.micro |
| Almacenamiento | 20 GB gp2 |
| Security Group | sg-rds-matias-fernandez (:3306 solo desde sg-ec2) |

> **Captura requerida:** EC2 en estado "running" + RDS en estado "available", ambos con naming correcto visible.

---

## Slide 09 — ALB, S3 y Servicios Corriendo

### ALB — Path-Based Routing

| Prioridad | Condición | Target Group | Puerto EC2 |
|---|---|---|---|
| 10 | `/api/productos*` | tg-productos-matias-fernandez | :3001 |
| 20 | `/api/pedidos*` | tg-pedidos-matias-fernandez | :3002 |
| Default | Cualquier otro path | Respuesta informativa 200 | — |

### S3 Static Website

| Atributo | Valor |
|---|---|
| Bucket | technova-frontend-matias-fernandez-20099194 |
| Static Website | Habilitado (index.html) |
| Acceso | Público (política GetObject) |

### Containers corriendo en EC2 (docker ps via SSM)

```
NAMES                       STATUS          PORTS
technova-api-productos      Up X minutes    0.0.0.0:3001->3001/tcp
technova-api-pedidos        Up X minutes    0.0.0.0:3002->3002/tcp
```

> **Captura requerida:** ALB con las 2 listener rules + ambos Target Groups en estado Healthy. Output de `docker ps` desde SSM.

---

## Slide 10 — La Aplicación Funcionando

### Endpoints de validación y autoría

**GET** `http://[alb-url]/api/productos/info`

```json
{
  "alumno": "Matias Fernandez",
  "rut": "20.099.194-k",
  "seccion": "ARY1101",
  "servicio": "api-productos",
  "status": "OK",
  "db_conectada": true
}
```

**GET** `http://[alb-url]/api/pedidos/info`

```json
{
  "alumno": "Matias Fernandez",
  "rut": "20.099.194-k",
  "seccion": "ARY1101",
  "servicio": "api-pedidos",
  "status": "OK",
  "db_conectada": true
}
```

**Frontend:** `http://technova-frontend-matias-fernandez-20099194.s3-website-us-east-1.amazonaws.com`

> **Captura requerida:** Browser con la tienda abierta desde URL de S3. Respuestas JSON de ambos /api/info desde ALB. Output del script `03_validate.sh` con todos los checks en verde.

---

## Apéndice — Justificación Técnica de Decisiones

### ¿Por qué S3 y no EC2+Nginx para el frontend?

El frontend es contenido 100% estático (HTML, JavaScript, CSS, imágenes). Nginx actuaba únicamente como servidor de archivos — sin lógica de negocio. S3 Static Website cumple exactamente esa función sin proceso de servidor, sin gestión de OS ni actualizaciones de seguridad. El costo es mínimo (~$0.50/mes vs ~$8.50/mes del EC2). El EC2 queda dedicado exclusivamente a las APIs que sí tienen lógica.

### ¿Por qué SSM Session Manager y no SSH?

LabInstanceProfile en el EC2 permite conectarse al OS vía AWS Systems Manager sin abrir el puerto 22. Esto reduce la superficie de ataque (sg-ec2 no tiene ingress :22) y sigue las recomendaciones de seguridad de AWS para acceso operacional en entornos de producción.

### ¿Por qué ECR para las imágenes Docker?

ECR es el registro nativo de AWS. El EC2 con LabInstanceProfile tiene permisos de pull automáticos sin gestionar credenciales adicionales. Es el flujo productivo real: build local → push a ECR → EC2 hace pull desde red privada.

### Mejoras futuras identificadas (post-POC, no parte de esta evaluación)

- **CloudFront** frente a S3 para HTTPS y CDN global
- **ACM Certificate** para TLS en el ALB
- **Auto Scaling Group** para el EC2 de APIs
- **RDS Multi-AZ** para alta disponibilidad
- **CloudWatch Alarms** y dashboards de monitoreo
- **AWS Backup** para snapshots automáticos
