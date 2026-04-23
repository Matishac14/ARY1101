# ==============================================================================
# TECNOVA - OUTPUTS
# Consumidos por los scripts 01, 02 y 03
# ==============================================================================

output "alb_dns_name" {
  description = "URL publica del ALB (solo APIs)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint privado MySQL para inyeccion via SSM"
  value       = aws_db_instance.mysql.address
}

output "ec2_instance_id" {
  description = "ID del EC2 (APIs) para SSM Session Manager"
  value       = aws_instance.app.id
}

output "s3_website_url" {
  description = "URL publica del frontend en S3 Static Website"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.main.id
}
