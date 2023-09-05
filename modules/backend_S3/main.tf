#  terraform {
#   required_version = ">= 0.12, < 0.13"
# } 

provider "aws" {
  region = "ap-northeast-2"

  # 2.x 버전의 AWS 공급자 허용
  version = "~> 5.7"
}

resource "aws_s3_bucket" "terraform_state" {

  bucket = "terraform-state-interface"
  force_destroy = true

  versioning {
    enabled = true
  }

  # 서버사이드 암호화 설정
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# resource "aws_dynamodb_table" "terraform_locks" {
#   name         = "terraform_state_lock"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }