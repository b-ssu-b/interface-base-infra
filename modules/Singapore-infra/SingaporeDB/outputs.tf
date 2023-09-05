output "RDS_Proxy_writer_endpoint_EP_Singapore" {
  value       = aws_db_proxy.RDS_Proxy_Singapore.endpoint
  sensitive = false
  description = "writer_endpoint_EP"
}

output "RDS_Proxy_reader_endpoint_EP_Singapore" {
  value       = aws_db_proxy_endpoint.read_only_EP.endpoint
  sensitive = false
  description = "reader_endpoint_EP"
}