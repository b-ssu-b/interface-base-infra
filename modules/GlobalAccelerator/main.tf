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

data "aws_lb" "Seoul_websrvlb" {
  provider = aws.Seoul
  arn  = var.Seoul_lb_arn
}

data "aws_lb" "Singapore_websrvlb" {
  provider = aws.Singapore
  arn  = var.Singapore_lb_arn
}

# S3 버켓-GA 로그 저장용
resource "aws_s3_bucket" "storage_for_logs" {
  provider = aws.Seoul
  bucket = "storage-for-logs-interface"
  force_destroy = true

  versioning { #버전 관리
    enabled = true
  }

  # 서버사이드 암호화 설정(SSE-S3)
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# 글로벌 엑셀러레이터
resource "aws_globalaccelerator_accelerator" "GlobalAccelerator" {
  name            = "interface-globalaccelerator"
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled   = true
    flow_logs_s3_bucket = aws_s3_bucket.storage_for_logs.bucket
    flow_logs_s3_prefix = "GlobalAccelerator/flow-logs/" #로그 저장될 폴더 이름
  }
}
#GA 리스너 규칙: tcp 80 - http
resource "aws_globalaccelerator_listener" "GA_listener" {
  accelerator_arn = aws_globalaccelerator_accelerator.GlobalAccelerator.id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}
#GA 엔드포인트 엔드포인틑 그룹-서울alb, 싱가폴alb
resource "aws_globalaccelerator_endpoint_group" "Seoul_EP" {
  listener_arn = aws_globalaccelerator_listener.GA_listener.id
  endpoint_group_region = "ap-northeast-2"

  endpoint_configuration {
    endpoint_id = data.aws_lb.Seoul_websrvlb.arn
    weight      = 100
    client_ip_preservation_enabled = true
  }
}
resource "aws_globalaccelerator_endpoint_group" "Singapore_EP" {
  listener_arn = aws_globalaccelerator_listener.GA_listener.id

  endpoint_group_region = "ap-southeast-1"

  endpoint_configuration {
    endpoint_id = data.aws_lb.Singapore_websrvlb.arn
    weight      = 100
    client_ip_preservation_enabled = true
  }
}

# # 라우트 53
# resource "aws_route53_zone" "websrvdomain" {
#   name = "bluelife.cloud"
# }
# #A레코드 생성: GA 배포 후 dns주소 A레코드로 등록
# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.websrvdomain.zone_id
#   name    = "www.bluelife.cloud"
#   type    = "A"

#   alias {
#     name                   = aws_globalaccelerator_accelerator.GlobalAccelerator.id
#     zone_id                = aws_globalaccelerator_accelerator.GlobalAccelerator.hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# #Seoul WAF
# resource "aws_wafv2_web_acl" "Seoul_web_acl" {
#   name        = "BlockAllWebTrafficExceptSeoulSingapore"
#   description = "Block all web traffic except from Seoul and Singapore"
#   scope       = "REGIONAL"
#   provider    = aws.Seoul
  

#   default_action {
#     block {}
#   }

#   rule {
#     name     = "SeoulappWAF"
#     priority = 0

#     action {
#       allow {}
#     }

#     statement {
#         geo_match_statement {
#           country_codes = ["KR", "SG"]
#         }
#     }

#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "monitoring-Seoul-waf-rule"
#       sampled_requests_enabled   = true
#     }
#   }
#   visibility_config {
#     cloudwatch_metrics_enabled = false
#     metric_name                = "monitoring-Seoul-waf"
#     sampled_requests_enabled   = false
#   }
# }
# #Web ACL 서울 ALB와 연결
# resource "aws_wafv2_web_acl_association" "waf_lb_association_Seoul" {
#   resource_arn = data.aws_lb.Seoul_websrvlb.arn
#   web_acl_arn  = aws_wafv2_web_acl.Seoul_web_acl.arn
# }

# #Sinagpore WAF
# resource "aws_wafv2_web_acl" "SG_web_acl" {
#   name        = "BlockAllWebTrafficExceptSeoulSingapore"
#   description = "Block all web traffic except from Seoul and Singapore"
#   scope       = "REGIONAL"  
#   provider    = aws.Singapore

#   default_action {
#     block {}
#   }

#   rule {
#     name     = "SGappWAF"
#     priority = 0

#     action {
#       allow {}
#     }

#     statement {
#         geo_match_statement {
#           country_codes = ["KR", "SG"]
#         }
#     }

#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "monitoring-waf-rule"
#       sampled_requests_enabled   = false
#     }
#   }
#   visibility_config {
#     cloudwatch_metrics_enabled = false
#     metric_name                = "monitoring-waf"
#     sampled_requests_enabled   = false
#   }
# }
# #Web ACL 싱가폴 ALB와 연결
# resource "aws_wafv2_web_acl_association" "waf_lb_association_Singapore" {
#   resource_arn = data.aws_lb.Singapore_websrvlb.arn
#   web_acl_arn  = aws_wafv2_web_acl.SG_web_acl.arn
# }