terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7"
    }
  }
}
provider "aws" {
  alias  = "Seoul"
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "Singapore"
  region = "ap-southeast-1"
}

data "aws_region" "peer" {
  provider = aws.Singapore
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-interface"
    key            = "TGW-Peering-terraform.tfstate"
    region         = "ap-northeast-2"
    # dynamodb_table = "terraform.tfstate-locking"
    encrypt        = true
  }
}

#s3에서 Seoul-terraform.tfstate 파일정보 가져오기
data "terraform_remote_state" "Seoul_infra" {
  backend = "s3"
  config = {
    bucket = "terraform-state-interface"
    key    = "Seoul-terraform.tfstate"
    region = "ap-northeast-2"
  }
}
#s3에서 Singapore-terraform.tfstate 파일정보 가져오기
data "terraform_remote_state" "SG_infra" {
  backend = "s3"
  config = {
    bucket = "terraform-state-interface"
    key    = "Singapore-terraform.tfstate"
    region = "ap-northeast-2"
  }
}

#TGW 피어링 연결: 서울에서 싱가폴로 요청
resource "aws_ec2_transit_gateway_peering_attachment" "Seoul_to_Singapore" {
  provider   = aws.Seoul
  peer_account_id         = data.terraform_remote_state.SG_infra.outputs.SingaporeTGW_owner_id
  peer_region             = data.aws_region.peer.name
  peer_transit_gateway_id = data.terraform_remote_state.SG_infra.outputs.SingaporeTGW_id
  transit_gateway_id      = data.terraform_remote_state.Seoul_infra.outputs.SeoulTGW_id

  tags = {
    Name = "Seoul-TGW Peering Requestor"
  }
}
#TGW 피어링 연결 수락: 싱가폴에서 수락
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "Singapore_accept" {
  provider   = aws.Singapore
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.Seoul_to_Singapore.id
  depends_on = [aws_ec2_transit_gateway_peering_attachment.Seoul_to_Singapore]
  tags = {
    Name = "Singapore-TGW Peering Accepter"
  }
}

#Seoul TGW RT에 TGW peering 연결 정적 라우팅 경로 등록
resource "aws_ec2_transit_gateway_route" "tgw_peering_route" {
  provider   = aws.Seoul
  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.Singapore_accept]
  destination_cidr_block         = "10.3.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.Seoul_to_Singapore.id
  transit_gateway_route_table_id = data.terraform_remote_state.Seoul_infra.outputs.SeoulTGW_RT_id
}
#Singapore TGW RT에 TGW peering 연결 정적 라우팅 경로 등록
resource "aws_ec2_transit_gateway_route" "vpn_route" {
  provider   = aws.Singapore
  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.Singapore_accept]
  destination_cidr_block         = "10.1.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.Seoul_to_Singapore.id
  transit_gateway_route_table_id = data.terraform_remote_state.SG_infra.outputs.SingaporeTGW_RT_id
}

