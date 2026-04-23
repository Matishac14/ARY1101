# ==============================================================================
# TECNOVA - VARIABLES
# ARY1101 · Matias Fernandez
# ==============================================================================

variable "alumno" {
  description = "Sufijo naming convention (nombre-apellido)"
  default     = "matias-fernandez"
}

variable "region" {
  description = "Region AWS (Learner Lab: us-east-1 o us-west-2)"
  default     = "us-east-1"
}

variable "db_name" {
  description = "Nombre BD: 'tienda_' + digitos RUT sin guion ni DV"
  default     = "tienda_20099194"
}

variable "db_user" {
  description = "Usuario administrador RDS"
  default     = "admin"
}

variable "db_password" {
  description = "Contrasena RDS"
  default     = "20099194k"
  sensitive   = true
}

variable "ec2_instance_type" {
  description = "Tipo EC2 para APIs (Learner Lab: hasta large)"
  default     = "t3.micro"
}

variable "s3_bucket_suffix" {
  description = "Sufijo unico para el bucket S3 del frontend (debe ser globalmente unico)"
  default     = "20099194"
}
