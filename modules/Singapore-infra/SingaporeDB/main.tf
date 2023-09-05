provider "aws" {
  region = "ap-southeast-1"

  # 2.x 버전의 AWS 공급자 허용
  version = "~> 5.7"
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-interface"
    key            = "Singapore-RDS-terraform.tfstate"
    region         = "ap-northeast-2"
    # dynamodb_table = "terraform.tfstate-locking"
    encrypt        = true
  }
}
# RDS Secret manager KMS Key 
data "aws_secretsmanager_secret_version" "rds_secret" { 
  #rds 시크릿정보(사용자명,비번) 시크릿매니저로 관리
  secret_id = "" #본인 시크릿 키 arn
}


#iam_role for RDS_Proxy
data "aws_iam_role" "RDS_Proxy_iam" {
  name = "" # 본인 rds proxy iam역할명 입력
}

data "terraform_remote_state" "terraform_state" {
  backend = "s3"

  config = {
    bucket = "terraform-state-interface"
    key    = "Singapore-terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "rds_terraform_state" {
  backend = "s3"

  config = {
    bucket = "terraform-state-interface"
    key    = "Seoul-RDS-terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Singapore Region Aurora Cluster Subnet group
resource "aws_db_subnet_group" "aws_aurora_subnet_group-Singapore" {
  name       = "rds_cluster_group"
  subnet_ids = [data.terraform_remote_state.terraform_state.outputs.aws_subnet_priSN3_Singapore, data.terraform_remote_state.terraform_state.outputs.aws_subnet_priSN4_Singapore]
  tags = {
    Name = "Singapore Aurora subnet group"
  }
}

# Singapore Region Aurora Cluster
resource "aws_rds_cluster" "Singapore_aurora_cluster" {
  apply_immediately       = true
  cluster_identifier      = "aurora-cluster-singapore"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.11.3"
  db_subnet_group_name    = aws_db_subnet_group.aws_aurora_subnet_group-Singapore.name
  vpc_security_group_ids = [data.terraform_remote_state.terraform_state.outputs.aws_security_group_Aurora_Singapore ]
  # database_name           = var.db_name
  backup_retention_period = 5
  skip_final_snapshot = true
  replication_source_identifier = data.terraform_remote_state.rds_terraform_state.outputs.rds_cluster_arn_seoul
  source_region = "ap-northeast-2"
#   preferred_backup_window = "07:00-09:00"
}

# Aurora Cluster Instance 
resource "aws_rds_cluster_instance" "aurora_instances" {
  count                 = 2  # Aurora 클러스터 인스턴스 수를 원하는 값으로 변경하세요.
  cluster_identifier    = aws_rds_cluster.Singapore_aurora_cluster.id
  identifier            = "singapore-database-${count.index}"
  engine                = "aurora-mysql"
  instance_class        = "db.t3.small"  # 원하는 인스턴스 유형으로 변경하세요.
  publicly_accessible   = false
}

# #RDS Proxy
resource "aws_db_proxy" "RDS_Proxy_Singapore" {
  name                   = "rds-proxy-singapore"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = data.aws_iam_role.RDS_Proxy_iam.arn       
  vpc_security_group_ids = [data.terraform_remote_state.terraform_state.outputs.aws_security_group_Aurora_Singapore ]
  vpc_subnet_ids         = aws_db_subnet_group.aws_aurora_subnet_group-Singapore.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  =  data.aws_secretsmanager_secret_version.rds_secret.arn

  }

  tags = {
    Name = "Singapore-RDS-Proxy"
    Key  = "value"
  }
}

# RDS Proxy 타겟 그룹 
resource "aws_db_proxy_default_target_group" "RDS_Proxy_target_group_Singapore" {
  db_proxy_name = aws_db_proxy.RDS_Proxy_Singapore.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

# RDS Proxy 타겟 EP
resource "aws_db_proxy_target" "RDS_Proxy_target" {
  db_cluster_identifier  = aws_rds_cluster.Singapore_aurora_cluster.cluster_identifier
  db_proxy_name          = aws_db_proxy.RDS_Proxy_Singapore.name
  target_group_name      = aws_db_proxy_default_target_group.RDS_Proxy_target_group_Singapore.name
}
# RDS Proxy readonly EP
resource "aws_db_proxy_endpoint" "read_only_EP" {
  db_proxy_name          = aws_db_proxy.RDS_Proxy_Singapore.name
  db_proxy_endpoint_name = "readonly"
  vpc_subnet_ids         = aws_db_subnet_group.aws_aurora_subnet_group-Singapore.subnet_ids
  target_role            = "READ_ONLY"
}