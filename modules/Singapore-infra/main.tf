terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7"
    }
  }
}
provider "aws" {
  region = "ap-southeast-1"
}

terraform {
  backend "s3" {
    # This backend configuration is filled in automatically at test time by Terratest. If you wish to run this example
    # manually, uncomment and fill in the config below.

    bucket         = "terraform-state-interface"
    key            = "Singapore-terraform.tfstate"
    region         = "ap-northeast-2"
    # dynamodb_table = "terraform.tfstate-locking"
    encrypt        = true
  }
}

#SingaporeVPC#
resource "aws_vpc" "Singapore-aws-vpc" {
  cidr_block = "10.3.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"
  tags = {
    Name = "Singapore-aws-vpc"
  }
}

#SingaporeIGW & IGW Attachement#
resource "aws_internet_gateway" "Singapore-IGW" {
  vpc_id = aws_vpc.Singapore-aws-vpc.id
  tags = {
    Name = "Singapore-IGW"
  }
}    

#Singapore 서브넷#
#퍼블릭sn#
resource "aws_subnet" "Singapore-PubSN1" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.1.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "Singapore-PubSN1"
  }
}
resource "aws_subnet" "Singapore-PubSN2" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.2.0/24"
  availability_zone = "ap-southeast-1c"
  tags = {
    Name = "Singapore-PubSN2"
  }
}
#프라이빗sn-for eks node#
resource "aws_subnet" "Singapore-PriSN1" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.3.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "Singapore-PriSN1"
  }
}
resource "aws_subnet" "Singapore-PriSN2" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.4.0/24"
  availability_zone = "ap-southeast-1c"
  tags = {
    Name = "Singapore-PriSN2"
  }
}
#프라이빗sn-for aurora db#
resource "aws_subnet" "Singapore-PriSN3" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.5.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "Singapore-PriSN3"
  }
}
resource "aws_subnet" "Singapore-PriSN4" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.6.0/24"
  availability_zone = "ap-southeast-1c"
  tags = {
    Name = "Singapore-PriSN4"
  }
}
#TGW 연동용 서브넷-private SN
resource "aws_subnet" "Singapore-Asso-SN1" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.7.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "Singapore-TGWAssociationSN1"
  }  
}
resource "aws_subnet" "Singapore-Asso-SN2" {
  vpc_id     = aws_vpc.Singapore-aws-vpc.id
  cidr_block = "10.3.8.0/24"
  availability_zone = "ap-southeast-1c"
  tags = {
    Name = "Singapore-TGWAssociationSN2"
  }  
}

#NAT Gateway:EIP & NATgateway
resource "aws_eip" "myEIP1" {
  domain = "vpc"
  depends_on                = [aws_internet_gateway.Singapore-IGW]
}
resource "aws_eip" "myEIP2" {
  domain = "vpc"
  depends_on                = [aws_internet_gateway.Singapore-IGW]
}

resource "aws_nat_gateway" "Singapore-NATGW1" {
  allocation_id = aws_eip.myEIP1.id
  subnet_id     = aws_subnet.Singapore-PubSN1.id
  tags = {
    Name = "Singapore-NATGW1"
  }

  depends_on = [aws_internet_gateway.Singapore-IGW]
}
resource "aws_nat_gateway" "Singapore-NATGW2" {
  allocation_id = aws_eip.myEIP2.id
  subnet_id     = aws_subnet.Singapore-PubSN2.id
  tags = {
    Name = "Singapore-NATGW2"
  }

  depends_on = [aws_internet_gateway.Singapore-IGW]
}

#Route Tables&Routing#
#PublicRT & IGW Routing#
resource "aws_route_table" "Singapore-aws-PubRT" {
  vpc_id = aws_vpc.Singapore-aws-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Singapore-IGW.id
  }
  route { #TGW라우팅 경로
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.SingaporeTGW.id
  }
  tags = {
    Name = "Singapore-aws-PubRT"
  }
}
#PrivateRT & NATgw Routing#
resource "aws_route_table" "Singapore-aws-PriRT1" {
  vpc_id = aws_vpc.Singapore-aws-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Singapore-NATGW1.id
  }
  tags = {
    Name = "Singapore-aws-PriRT1"
  }  
}
resource "aws_route_table" "Singapore-aws-PriRT2" {
  vpc_id = aws_vpc.Singapore-aws-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Singapore-NATGW2.id
  }  
  tags = {
    Name = "Singapore-aws-PriRT2"
  }
}

#Route Tables Assosiation#
#퍼블릭
resource "aws_route_table_association" "PubRoute1" {
  subnet_id      = aws_subnet.Singapore-PubSN1.id
  route_table_id = aws_route_table.Singapore-aws-PubRT.id
}
resource "aws_route_table_association" "PubRoute2" {
  subnet_id      = aws_subnet.Singapore-PubSN2.id
  route_table_id = aws_route_table.Singapore-aws-PubRT.id
}
#EKS 배포용
resource "aws_route_table_association" "PriRoute1" {
  subnet_id      = aws_subnet.Singapore-PriSN1.id
  route_table_id = aws_route_table.Singapore-aws-PriRT1.id
}
resource "aws_route_table_association" "PriRoute2" {
  subnet_id      = aws_subnet.Singapore-PriSN2.id
  route_table_id = aws_route_table.Singapore-aws-PriRT2.id
}
#db인스턴스용
resource "aws_route_table_association" "PriRoute3" {
  subnet_id      = aws_subnet.Singapore-PriSN3.id
  route_table_id = aws_route_table.Singapore-aws-PriRT1.id
}
resource "aws_route_table_association" "PriRoute4" {
  subnet_id      = aws_subnet.Singapore-PriSN4.id
  route_table_id = aws_route_table.Singapore-aws-PriRT2.id
}

#SG-default#
resource "aws_security_group" "Singapore-default" {
  name = "Singapore-defaultSG"
  description = "allow inbound traffic"
  vpc_id      = aws_vpc.Singapore-aws-vpc.id

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

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#SG-Database
resource "aws_security_group" "Singapore-Aurora" {
  
  name = "Seoul-AuroraSG"
  description = "allow inbound traffic"
  vpc_id      = aws_vpc.Singapore-aws-vpc.id
  ingress {
    description      = "allow 3306 port for Websrv"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    # security_groups = [ aws_security_group.Singapore-default.id ]
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
  ami           = "ami-0b3a4110c36b9a5f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.Singapore-PubSN2.id
  key_name      = var.keypair_name
  security_groups = [aws_security_group.Singapore-default.id]
  associate_public_ip_address = true
  private_ip    = "10.3.2.100"
  tags = {
    Name = "Singapore-testweb1"
  }
  user_data = data.template_file.test_user_data.rendered
}
data "template_file" "test_user_data" {
  template = file("test-user-data.sh")
}

##TGW##
resource "aws_ec2_transit_gateway" "SingaporeTGW" {
  tags = {
    Name = "SingaporeTGW"
  }
}
#TGW연결1 생성: TGW-서울vpc 연결 (vpc peering)
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-vpc-Att3" {
  subnet_ids         = [aws_subnet.Singapore-Asso-SN1.id, aws_subnet.Singapore-Asso-SN2.id]
  transit_gateway_id = aws_ec2_transit_gateway.SingaporeTGW.id
  vpc_id             = aws_vpc.Singapore-aws-vpc.id

  tags = {
    Name = "tgw-vpc-Att3"
  }
}


