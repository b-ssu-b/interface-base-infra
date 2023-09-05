data "terraform_remote_state" "terraform_state" {
  backend = "s3"

  config = {
    bucket = "terraform-state-interface"
    key    = "Singapore-terraform.tfstate"
    region = "ap-northeast-2"
  }
}


module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name                    = local.cluster_name
  cluster_version                 = "1.24"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id     = data.terraform_remote_state.terraform_state.outputs.singapore_vpc_id
# subnet_ids = [data.terraform_remote_state.terraform_state.outputs.aws_subnet_priSN1_Seoul, data.terraform_remote_state.terraform_state.outputs.aws_subnet_priSN2_Seoul]
  subnet_ids = ["subnet-05322d3765a03c157", "subnet-06b066ad0f3634872"]
  cloudwatch_log_group_retention_in_days = 1

  eks_managed_node_group_defaults = {
    instance_types = ["t3.small"]
    public_ip      = false  # 이 부분을 추가하여 공인 IP 주소 비활성화
  }

  eks_managed_node_groups = {
    green = {
      min_size     = 1
      max_size     = 2
      desired_size = 2

      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"
      public_ip      = false
    }
  }
}


