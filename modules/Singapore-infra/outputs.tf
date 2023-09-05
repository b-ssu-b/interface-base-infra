#일반 모듈 출력변수: 특정 환경의 루트 모듈이 특정 리소스를 참조하기 위한 용
output "singapore_vpc_id" {
  value       = aws_vpc.Singapore-aws-vpc.id
  description = "VPC ID of Singapore-aws-vpc"
}
output "aws_subnet_priSN1_Singapore" {
  value       = aws_subnet.Singapore-PriSN1.id
  description = "Eks-cluster subnet of Singapore-aws-vpc"
}

output "aws_subnet_priSN2_Singapore" {
  value       = aws_subnet.Singapore-PriSN2.id
  description = "Eks-cluster subnet of Singapore-aws-vpc"
}
output "aws_security_group" {
  value       = aws_security_group.Singapore-default.id
  description = "VPC ID of Singapore-aws-vpc"
}

output "aws_subnet_priSN3_Singapore" {
  value       = aws_subnet.Singapore-PriSN3.id
  description = "RDS subnet of Singapore-aws-vpc"
}

output "aws_subnet_priSN4_Singapore" {
  value       = aws_subnet.Singapore-PriSN4.id
  description = "RDS subnet of Singapore-aws-vpc"
}

output "aws_security_group_Aurora_Singapore" {
  value       = aws_security_group.Singapore-Aurora.id
  description = "RDS security group Singapore"
}

output "SingaporeTGW_id" {
  value       = aws_ec2_transit_gateway.SingaporeTGW.id
  description = "For TGW peering connection. Singapore TGW id"
}
output "SingaporeTGW_owner_id" {
  value       = aws_ec2_transit_gateway.SingaporeTGW.owner_id
  description = "For TGW peering connection. Singapore TGW owner id"
}
output "SingaporeTGW_RT_id" {
  value       = aws_ec2_transit_gateway.SingaporeTGW.association_default_route_table_id
  description = "SingaporeTGW default Route Table id"
}