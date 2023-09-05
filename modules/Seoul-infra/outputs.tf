#일반 모듈 출력변수: 특정 환경의 루트 모듈이 특정 리소스를 참조하기 위한 용도
#data.terraform_remote_state.terraform_state.outputs.출력변수명(뽑을 정보값 찾기)
output "seoul_vpc_id" {
  value       = aws_vpc.Seoul-aws-vpc.id
  description = "vpc id of Seoul-aws-vpc"
}
output "aws_subnet_priSN1_Seoul" {
  value       = aws_subnet.Seoul-PriSN1.id
  description = "Eks-cluster subnet of Seoul-aws-vpc"
}

output "aws_subnet_priSN2_Seoul" {
  value       = aws_subnet.Seoul-PriSN2.id
  description = "Eks-cluster subnet of Seoul-aws-vpc"
}
output "aws_subnet_priSN3_Seoul" {
  value       = aws_subnet.Seoul-PriSN3.id
  description = "RDS subnet of Seoul-aws-vpc"
}

output "aws_subnet_priSN4_Seoul" {
  value       = aws_subnet.Seoul-PriSN4.id
  description = "RDS subnet of Seoul-aws-vpc"
}

output "aws_subnet_IDC_Seoul" {
  value       = aws_subnet.IDC-PubSN.id
  description = "Public subnet of IDC-Seoul"
}

output "aws_security_group_Aurora_Seoul" {
  value       = aws_security_group.Seoul-Aurora.id
  description = "RDS security group Seoul"
}

output "aws_security_group_IDC_DB" {
  value       = aws_security_group.IDCDB-SG.id
  description = "IDC DB Secrurity group Seoul"
}

output "IDC_DB_PrivateIP" {
  value       = aws_instance.IDC-DB.private_ip
  description = "PrivateIP of IDC DB"
}

output "CGW_device_id" {
  value = aws_instance.IDC-CGW.public_ip
  description = "id of IDC CGW device"
}

output "vpn_tunnel1_ip" {
  value = aws_vpn_connection.IDCvpn_TGW.tunnel1_address
  description = "ip of tunnel1"
}

output "aws_vpn_connection_id" {
  value       = aws_vpn_connection.IDCvpn_TGW.id
  description = "vpn connection ID of IDCvpn-TGW"
}

output "SeoulTGW_id" {
  value       = aws_ec2_transit_gateway.SeoulTGW.id
  description = "For TGW peering connection. Seoul TGW id"
}

output "SeoulTGW_RT_id" {
  value       = aws_ec2_transit_gateway.SeoulTGW.association_default_route_table_id
  description = "SeoulTGW default Route Table id"
}