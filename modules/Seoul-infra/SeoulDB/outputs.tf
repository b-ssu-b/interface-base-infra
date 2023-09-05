
output "writer_endpoint_EP_Seoul" {
  value       = aws_db_proxy.RDS_Proxy.endpoint
  sensitive = false
  description = "writer_endpoint_EP"
}

output "reader_endpoint_EP_Seoul" {
  value       = aws_db_proxy_endpoint.read_only_EP.endpoint
  sensitive = false
  description = "reader_endpoint_EP"
}

output "rds_cluster_arn_seoul" {
  value       = aws_rds_cluster.Seoul_aurora_cluster.arn
  sensitive = false
  description = "rds_cluster_arn_seoul"
}

