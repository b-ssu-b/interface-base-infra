#서울 리전 배포
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7"
    }
  }
}
provider "aws" {
  region = "ap-northeast-2"
}


terraform {
  backend "s3" {
    # This backend configuration is filled in automatically at test time by Terratest. If you wish to run this example
    # manually, uncomment and fill in the config below.

    bucket         = "terraform-state-interface"
    key            = "Seoul-terraform.tfstate"
    region         = "ap-northeast-2"
    # dynamodb_table = "terraform.tfstate-locking"
    encrypt        = true
  }
}

#SeoulVPC#
resource "aws_vpc" "Seoul-aws-vpc" {
  
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"
  tags = {
    Name = "Seoul-aws-vpc"
  }
}

#SeoulIGW & IGW Attachement#
resource "aws_internet_gateway" "Seoul-IGW" {
    
  vpc_id = aws_vpc.Seoul-aws-vpc.id
  tags = {
    Name = "Seoul-IGW"
  }
}    

#Seoul 서브넷#
#퍼블릭sn#
resource "aws_subnet" "Seoul-PubSN1" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "Seoul-PubSN1"
  }
}
resource "aws_subnet" "Seoul-PubSN2" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.2.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "Seoul-PubSN2"
  }
}
#프라이빗sn-for eks node#
resource "aws_subnet" "Seoul-PriSN1" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.3.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "Seoul-PriSN1"
  }
}
resource "aws_subnet" "Seoul-PriSN2" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.4.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "Seoul-PriSN2"
  }
}
#프라이빗sn-for aurora db#
resource "aws_subnet" "Seoul-PriSN3" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.5.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "Seoul-PriSN3"
  }
}
resource "aws_subnet" "Seoul-PriSN4" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.6.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "Seoul-PriSN4"
  }
}
#TGW 연동용 서브넷-private SN
resource "aws_subnet" "Seoul-Asso-SN1" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.7.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "Seoul-TGWAssociationSN1"
  }  
}
resource "aws_subnet" "Seoul-Asso-SN2" {
  
  vpc_id     = aws_vpc.Seoul-aws-vpc.id
  cidr_block = "10.1.8.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "Seoul-TGWAssociationSN2"
  }  
}

#NAT Gateway:EIP & NATgateway
resource "aws_eip" "myEIP1" {
  
  domain = "vpc"
  depends_on                = [aws_internet_gateway.Seoul-IGW]
}
resource "aws_eip" "myEIP2" {
  
  domain = "vpc"
  depends_on                = [aws_internet_gateway.Seoul-IGW]
}

resource "aws_nat_gateway" "Seoul-NATGW1" {
  
  allocation_id = aws_eip.myEIP1.id
  subnet_id     = aws_subnet.Seoul-PubSN1.id
  tags = {
    Name = "Seoul-NATGW1"
  }

  depends_on = [aws_subnet.Seoul-PubSN2, aws_eip.myEIP1]
}
resource "aws_nat_gateway" "Seoul-NATGW2" {
  
  allocation_id = aws_eip.myEIP2.id
  subnet_id     = aws_subnet.Seoul-PubSN2.id
  tags = {
    Name = "Seoul-NATGW2"
  }

  depends_on = [aws_subnet.Seoul-PubSN2, aws_eip.myEIP2]
}

#Route Tables&Routing#
#PublicRT & IGW Routing#
resource "aws_route_table" "Seoul-aws-PubRT" {
  
  vpc_id = aws_vpc.Seoul-aws-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Seoul-IGW.id
  }
  route { #TGW라우팅 경로
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.SeoulTGW.id
  }
  tags = {
    Name = "Seoul-aws-PubRT"
  }
}
#PrivateRT & NATgw Routing#
resource "aws_route_table" "Seoul-aws-PriRT1" {
  
  vpc_id = aws_vpc.Seoul-aws-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Seoul-NATGW1.id
  }
  route { #TGW라우팅 경로:dms 복제인스턴스 태스크 실행 목적
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.SeoulTGW.id
  }
  tags = {
    Name = "Seoul-aws-PriRT1"
  }  
}
resource "aws_route_table" "Seoul-aws-PriRT2" {
  
  vpc_id = aws_vpc.Seoul-aws-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Seoul-NATGW2.id
  }  
  route { #TGW라우팅 경로:dms 복제인스턴스 태스크 실행 목적
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.SeoulTGW.id
  }
  tags = {
    Name = "Seoul-aws-PriRT2"
  }
}

#Route Tables Assosiation#
#퍼블릭
resource "aws_route_table_association" "PubRoute1" {
  subnet_id      = aws_subnet.Seoul-PubSN1.id
  route_table_id = aws_route_table.Seoul-aws-PubRT.id
}
resource "aws_route_table_association" "PubRoute2" {
  
  subnet_id      = aws_subnet.Seoul-PubSN2.id
  route_table_id = aws_route_table.Seoul-aws-PubRT.id
}
#EKS 배포용
resource "aws_route_table_association" "PriRoute1" {
  subnet_id      = aws_subnet.Seoul-PriSN1.id
  route_table_id = aws_route_table.Seoul-aws-PriRT1.id
}
resource "aws_route_table_association" "PriRoute2" {
  subnet_id      = aws_subnet.Seoul-PriSN2.id
  route_table_id = aws_route_table.Seoul-aws-PriRT2.id
}
#db인스턴스용
resource "aws_route_table_association" "PriRoute3" {
  subnet_id      = aws_subnet.Seoul-PriSN3.id
  route_table_id = aws_route_table.Seoul-aws-PriRT1.id
}
resource "aws_route_table_association" "PriRoute4" {
  subnet_id      = aws_subnet.Seoul-PriSN4.id
  route_table_id = aws_route_table.Seoul-aws-PriRT2.id
}

#SG-default#
resource "aws_security_group" "Seoul-default" {
  name = "Seoul-defaultSG"
  description = "allow inbound traffic"
  vpc_id      = aws_vpc.Seoul-aws-vpc.id

  ingress {
    description      = "allow 80 port for eks cluster"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "allow 80 port for eks cluster"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
  ingress {
    description      = "allow 8080 port for eks cluster"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  #노드포트는 9000~9003사용
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#SG-Database
resource "aws_security_group" "Seoul-Aurora" {
  name = "Seoul-AuroraSG"
  description = "allow inbound traffic"
  vpc_id      = aws_vpc.Seoul-aws-vpc.id
#테스트를 위해 모든 포트 리스닝하는 인그리스 규칙 생성
  ingress {
    description      = "allow all ips and ports for test"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    # security_groups = [ aws_security_group.Seoul-default.id ]
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# #ALB# eks에서 로드 밸런서 컨트롤러에 의해 프로비저닝되므로 제외
#테스트용 퍼블릭 웹 인스턴스#
resource "aws_instance" "webtest1" {
  ami           = "ami-03db74b70e1da9c56"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.Seoul-PubSN2.id
  key_name      = var.keypair_name
  security_groups = [aws_security_group.Seoul-default.id]
  associate_public_ip_address = true
  private_ip    = "10.1.2.100"
  tags = {
    Name = "seoul-testweb1"
  }
  user_data = data.template_file.test_user_data.rendered
}

data "template_file" "test_user_data" {
  template = file("test-user-data.sh")
}

####IDC####
#IDCVPC#
resource "aws_vpc" "IDC-vpc" {
  cidr_block = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"
  tags = {
    Name = "IDC-vpc"
  }
}

#SeoulIGW & IGW Attachement#
resource "aws_internet_gateway" "IDC-IGW" {
  vpc_id = aws_vpc.IDC-vpc.id
  tags = {
    Name = "IDC-IGW"
  }
}    
#IDC 퍼블릭sn#
resource "aws_subnet" "IDC-PubSN" {
  vpc_id     = aws_vpc.IDC-vpc.id
  cidr_block = "10.2.1.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "IDC-PubSN"
  }
}
#IDC public RT
resource "aws_route_table" "IDC-PubRT" {
  vpc_id = aws_vpc.IDC-vpc.id
  # depends_on   = [aws_ec2_transit_gateway_vpc_attachment.tgw-vpc-Att1]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IDC-IGW.id
  }
  route { #CGW 라우팅 경로
    cidr_block = "10.0.0.0/8"
    network_interface_id = aws_network_interface.CGW_eni.id
  }
  tags = {
    Name = "Seoul-idc-PubRT"
  }
}

#idc 퍼블릭RT-SN 연결
resource "aws_route_table_association" "IDCPubRoute" {
  subnet_id      = aws_subnet.IDC-PubSN.id
  route_table_id = aws_route_table.IDC-PubRT.id
}
##idc보안그룹##
#IDC CGW인스턴스 보안그룹-논의 후 수정
resource "aws_security_group" "IDCCGW-SG" { 
  vpc_id      = aws_vpc.IDC-vpc.id
  name = "IDCCGW-SG"
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress { #mysql
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }    
  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port        = 500
    to_port          = 500
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port        = 4500
    to_port          = 4500
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port        = 4500
    to_port          = 4500
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }     
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
}
#SG-IDC DB
resource "aws_security_group" "IDCDB-SG" { 
  vpc_id      = aws_vpc.IDC-vpc.id
  name = "IDCDB-SG"
  ingress { #ssh
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
  ingress { #http
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress { #mysql
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }        
  ingress { #icmp
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
     
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
}
#SG-IDC web
resource "aws_security_group" "IDCweb-SG" { 
  vpc_id      = aws_vpc.IDC-vpc.id
  name = "IDCweb-SG"
  ingress { #ssh
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
  ingress { #http
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress { #https
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }        
  ingress { #icmp
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
     
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
}
#IDC web 인스턴스: 모놀리식 애플리케이션 삽입-공인ip 부여
resource "aws_instance" "IDC-web" {
  ami           = "ami-07b7be0099924913e" #ubuntu
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.IDC-PubSN.id
  key_name      = var.keypair_name
  security_groups = [aws_security_group.IDCweb-SG.id]
  associate_public_ip_address = true
  private_ip    = "10.2.1.101"
  tags = {
    Name = "IDC-APP"
  }
  user_data = data.template_file.IDCweb_user_data.rendered
}

data "template_file" "IDCweb_user_data" {
  template = file("idc-web-user-data.sh")
}

#DB 인스턴스: 공인ip 부여
resource "aws_instance" "IDC-DB" {
  ami           = "ami-03db74b70e1da9c56"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.IDC-PubSN.id
  key_name      = var.keypair_name
  security_groups = [aws_security_group.IDCDB-SG.id]
  associate_public_ip_address = true
  private_ip    = "10.2.1.100"
  tags = {
    Name = "IDC-DB"
  }
  user_data = data.template_file.IDCDB_user_data.rendered
}

data "template_file" "IDCDB_user_data" {
  template = file("idcdb-user-data.sh")
}

#IDC CGW instance resources#
#CGW EIP
resource "aws_eip" "CGWEIP" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.IDC-IGW]
}
#CGW ENI
resource "aws_network_interface" "CGW_eni" {
  subnet_id       = aws_subnet.IDC-PubSN.id
  private_ips     = ["10.2.1.150"]
  security_groups = [aws_security_group.IDCCGW-SG.id]
  source_dest_check = false
}
#CGW ENI+EIP Association
resource "aws_eip_association" "CGWeip_asso" {
  network_interface_id   = aws_network_interface.CGW_eni.id
  allocation_id = aws_eip.CGWEIP.id
}
#IDC CGW인스턴스: CGW Device
resource "aws_instance" "IDC-CGW" {
  ami           = "ami-03db74b70e1da9c56"
  instance_type = "t2.micro"
  key_name      = var.keypair_name
  # associate_public_ip_address = true
  network_interface {
    network_interface_id = aws_network_interface.CGW_eni.id
    device_index         = 0
  }
  tags = {
    Name = "IDC-CGW"
  }
  user_data = data.template_file.CGW_user_data.rendered
}

data "template_file" "CGW_user_data" {
  template = file("idccgw-user-data.sh")
}

#idc 고객 게이트웨이 생성
resource "aws_customer_gateway" "IDC" {
  device_name = "IDC-CGW" #CGW디바이스명
  bgp_asn    = 65000
  ip_address = aws_eip.CGWEIP.public_ip
  type       = "ipsec.1"

  tags = {
    Name = "IDC-VPN-CGW"
  }
}
#site to site VPN 연결 생성 -> TGW 연결2 자동 연결
resource "aws_vpn_connection" "IDCvpn_TGW" {
  customer_gateway_id = aws_customer_gateway.IDC.id
  transit_gateway_id  = aws_ec2_transit_gateway.SeoulTGW.id #aws-idc연결 대상 게이트웨이:전송 게이트웨이
  type                = aws_customer_gateway.IDC.type
  static_routes_only = true
  
  tunnel1_preshared_key = "interface"
  tunnel2_preshared_key = "interface"

  tags = {
    Name = "IDCvpn_TGW"
  }  
}

##TGW##
resource "aws_ec2_transit_gateway" "SeoulTGW" {
  tags = {
    Name = "SeoulTGW"
  }
}
#TGW연결1 생성: TGW-서울vpc 연결 (vpc peering)
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-vpc-Att1" {
  subnet_ids         = [aws_subnet.Seoul-Asso-SN1.id, aws_subnet.Seoul-Asso-SN2.id]
  transit_gateway_id = aws_ec2_transit_gateway.SeoulTGW.id
  vpc_id             = aws_vpc.Seoul-aws-vpc.id

  tags = {
    Name = "tgw-vpc-Att1"
  }
}

#vpn tgw테이블에 정적 라우팅 경로 등록
resource "aws_ec2_transit_gateway_route" "vpn_route" {
  destination_cidr_block         = "10.2.0.0/16"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.idcvpn.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.SeoulTGW.association_default_route_table_id
}

data "aws_ec2_transit_gateway_vpn_attachment" "idcvpn" {
  depends_on = [aws_vpn_connection.IDCvpn_TGW]  
  transit_gateway_id = aws_ec2_transit_gateway.SeoulTGW.id
  vpn_connection_id  = aws_vpn_connection.IDCvpn_TGW.id
}


