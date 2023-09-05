provider "aws" {
  region = "ap-northeast-2"
  version = "~> 5.7"
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-interface"
    key            = "Seoul-RDS-terraform.tfstate"
    region         = "ap-northeast-2"
    # dynamodb_table = "terraform.tfstate-locking"
    encrypt        = true
  }
}

#인프라 배포 state 파일 불러오기
data "terraform_remote_state" "terraform_state" {
  backend = "s3"

  config = {
    bucket = "terraform-state-interface"
    key    = "Seoul-terraform.tfstate"
    region = "ap-northeast-2"
  }
}


data "aws_kms_key" "dms_key" {
  key_id = "" #본인 kms aws/dms 키로 교체
} 

#iam_role for RDS_Proxy: rds proxy 생성할 iam 역할 데이터 소스로 불러오기
data "aws_iam_role" "RDS_Proxy_iam" {
  name = "" # 본인 rds proxy iam역할명 입력
}

data "aws_secretsmanager_secret_version" "rds_secret" { 
  #rds 시크릿정보(사용자명,비번) 시크릿매니저로 관리
  secret_id = "" #본인 시크릿 키 arn
}

# Seoul Region Aurora Cluster Subnet group: 오로라 클러스터 서브넷 그룹 생성
resource "aws_db_subnet_group" "aws_aurora_subnet_group" {
  name       = "rds_cluster_group"
  subnet_ids = [data.terraform_remote_state.terraform_state.outputs.aws_subnet_priSN3_Seoul, data.terraform_remote_state.terraform_state.outputs.aws_subnet_priSN4_Seoul]
  tags = {
    Name = "Seoul Aurora subnet group"
  }
}

resource "aws_rds_cluster_parameter_group" "rds_cluster_Seoul" {
  name        = "rds-cluster-seoul"
  family      = "aurora-mysql5.7"
  description = "RDS default cluster parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }

  parameter {
    name  = "binlog_format"
    value = "ROW"
    apply_method = "pending-reboot"
  }  
}

# Seoul Region Aurora Cluster: 서울쪽에 오로라 클러스터 생성
resource "aws_rds_cluster" "Seoul_aurora_cluster" {
  apply_immediately       = true
  cluster_identifier      = "aurora-cluster-seoul"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.11.3"
  db_subnet_group_name    = aws_db_subnet_group.aws_aurora_subnet_group.name
  vpc_security_group_ids = [ data.terraform_remote_state.terraform_state.outputs.aws_security_group_Aurora_Seoul ]
  database_name           = var.db_name
  master_username         = jsondecode(data.aws_secretsmanager_secret_version.rds_secret.secret_string)["username"] #마스터 사용자 이름
  master_password         = jsondecode(data.aws_secretsmanager_secret_version.rds_secret.secret_string)["password"] #마스터 사용자 암호
  backup_retention_period = 5
  skip_final_snapshot = true
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.rds_cluster_Seoul.name
#   preferred_backup_window = "07:00-09:00"
}

# Aurora Cluster Instance 
resource "aws_rds_cluster_instance" "primary" {
  cluster_identifier    = aws_rds_cluster.Seoul_aurora_cluster.id
  identifier            = "seoul-database-2"
  engine                = "aurora-mysql"
  instance_class        = "db.t3.small"  # 원하는 인스턴스 유형으로 변경하세요.
  publicly_accessible   = false
}

resource "aws_rds_cluster_instance" "secondary" {
  cluster_identifier    = aws_rds_cluster.Seoul_aurora_cluster.id
  identifier            = "seoul-database-3"
  engine                = "aurora-mysql"
  instance_class        = "db.t3.small"  # 원하는 인스턴스 유형으로 변경하세요.
  publicly_accessible   = false
}


#RDS Proxy
resource "aws_db_proxy" "RDS_Proxy" {
#   depends_on = [ aws_rds_cluster.Seoul_aurora_cluster ]
  name                   = "rds-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = false
  role_arn               = data.aws_iam_role.RDS_Proxy_iam.arn       
  vpc_security_group_ids = [ data.terraform_remote_state.terraform_state.outputs.aws_security_group_Aurora_Seoul ]
  vpc_subnet_ids         = aws_db_subnet_group.aws_aurora_subnet_group.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  =  data.aws_secretsmanager_secret_version.rds_secret.arn

  }

  tags = {
    Name = "Seoul-RDS-Proxy"
    Key  = "value"
  }
}

# RDS Proxy 타겟 그룹 
resource "aws_db_proxy_default_target_group" "RDS_Proxy_target_group" {
  db_proxy_name = aws_db_proxy.RDS_Proxy.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

# RDS Proxy 타겟 
resource "aws_db_proxy_target" "RDS_Proxy_target" {
  db_cluster_identifier  = aws_rds_cluster.Seoul_aurora_cluster.cluster_identifier
  db_proxy_name          = aws_db_proxy.RDS_Proxy.name
  target_group_name      = aws_db_proxy_default_target_group.RDS_Proxy_target_group.name
}

resource "aws_db_proxy_endpoint" "read_only_EP" {
  db_proxy_name          = aws_db_proxy.RDS_Proxy.name
  db_proxy_endpoint_name = "readonly"
  vpc_subnet_ids         = aws_db_subnet_group.aws_aurora_subnet_group.subnet_ids
  vpc_security_group_ids = [ data.terraform_remote_state.terraform_state.outputs.aws_security_group_Aurora_Seoul ]
  target_role            = "READ_ONLY"
}

# 복제 인스턴스 서브넷 그룹 생성 
# Create a new replication subnet group
resource "aws_dms_replication_subnet_group" "Replication_subnet_group" {
  replication_subnet_group_description = "subnetgroup of replication instance"
  replication_subnet_group_id          = "replication-subent-group"
  subnet_ids = aws_db_subnet_group.aws_aurora_subnet_group.subnet_ids

}

# 복제 인스턴스 생성 
resource "aws_dms_replication_instance" "replication_instance" {
  allocated_storage            = 20
  apply_immediately            = true
  auto_minor_version_upgrade   = true
  availability_zone            = "ap-northeast-2a"
  engine_version               = "3.5.1"
  kms_key_arn                  = data.aws_kms_key.dms_key.arn
  multi_az                     = false
  # preferred_maintenance_window = "sun:10:30-sun:14:30"
  publicly_accessible          = true
  replication_instance_class   = "dms.t3.micro"
  replication_instance_id      = "replication-instance"
  replication_subnet_group_id  = aws_dms_replication_subnet_group.Replication_subnet_group.id
  vpc_security_group_ids = [
    data.terraform_remote_state.terraform_state.outputs.aws_security_group_Aurora_Seoul
  ]
}

# Source DMS 엔드포인트 
resource "aws_dms_endpoint" "Source_EP" {
  # database_name               = "source-database"
  endpoint_id                 = "source-database"
  endpoint_type               = "source"
  engine_name                 = "mariadb"
  kms_key_arn                 = data.aws_kms_key.dms_key.arn
  password                    = "qwe123"
  port                        = 3306
  server_name                 = data.terraform_remote_state.terraform_state.outputs.IDC_DB_PrivateIP
  ssl_mode                    = "none"
  username                    = "gasida"
}

# Target DMS 엔드포인트 
resource "aws_dms_endpoint" "Target_EP" {
  # database_name               = "target-database"
  endpoint_id                 = "target-database"
  endpoint_type               = "target"
  engine_name                 = "aurora"
  kms_key_arn                 = data.aws_kms_key.dms_key.arn
  password                    = jsondecode(data.aws_secretsmanager_secret_version.rds_secret.secret_string)["password"]
  port                        = 3306
  server_name                 = aws_rds_cluster_instance.primary.endpoint
  ssl_mode                    = "none"
  username                    = "admin"
}


# # Create a new replication task
# resource "aws_dms_replication_task" "test" {
#   cdc_start_time            = 1484346880
#   migration_type            = "full-load"
#   replication_instance_arn  = aws_dms_replication_instance.replication_instance.replication_instance_arn
#   replication_task_id       = "dmstask-mariadb-aurora"
#   replication_task_settings = <<EOF
# {
#   "TargetMetadata": {
#     "TargetSchema": "",
#     "FullLobMode": true,
#     "LobChunkSize": 64,
#     "LimitedSizeLobMode": false
#   },
#   "FullLoadSettings": {
#     "TargetTablePrepMode": "TRUNCATE_BEFORE_LOAD",
#     "CreatePkAfterFullLoad": false,
#     "StopTaskCachedChangesApplied": false,
#     "StopTaskCachedChangesNotApplied": false,
#     "MaxFullLoadSubTasks": 8,
#     "TransactionConsistencyTimeout": 600,
#     "CommitRate": 10000
#   }
# }
# EOF

#   source_endpoint_arn       = aws_dms_endpoint.Source_EP.endpoint_arn
#   table_mappings            = <<EOF
# {
#   "rules": [
#     {
#       "rule-type": "selection",
#       "rule-id": "1",
#       "rule-name": "1",
#       "object-locator": {
#         "schema-name": "public",
#         "table-name": "%"
#       },
#       "rule-action": "include"
#     }
#   ]
# }
# EOF

#   tags = {
#     Name = "idc-aws-task"
#   }

#   target_endpoint_arn = aws_dms_endpoint.Target_EP.endpoint_arn
# }