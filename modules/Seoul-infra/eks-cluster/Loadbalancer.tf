data "terraform_remote_state" "terraform_state" {
  backend = "s3"

  config = {
    bucket = "terraform-state-interface"
    key    = "Seoul-terraform.tfstate"
    region = "ap-northeast-2"
  }
}


locals {
  cluster_name = "Seoul-eks-cluster"
  lb_controller_iam_role_name         = "inhouse-eks-aws-lb-ctrl"
  lb_controller_service_account_name  = "aws-load-balancer-controller"
  efs_controller_iam_role_name        = "inhouse-eks-aws-efs-ctrl"
  efs_controller_service_account_name = "aws-efs-controller"
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.this.token
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  }
}

module "lb_controller_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role = true

  role_name        = local.lb_controller_iam_role_name
  role_path        = "/"
  role_description = "Used by AWS Load Balancer Controller for EKS"

  role_permissions_boundary_arn = ""

  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:${local.lb_controller_service_account_name}"
  ]
  oidc_fully_qualified_audiences = [
    "sts.amazonaws.com"
  ]
}

data "http" "iam_policy_loadbalancer" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json"
}

resource "aws_iam_role_policy" "controller" {
  name_prefix = "AWSLoadBalancerControllerIAMPolicy"
  policy      = data.http.iam_policy_loadbalancer.body
  role        = module.lb_controller_role.iam_role_name
}

resource "helm_release" "release" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"

  
  dynamic "set" {
    for_each = {
      "clusterName"           = module.eks.cluster_name
      "serviceAccount.create" = "true"
      "serviceAccount.name"   = local.lb_controller_service_account_name
      "region"                = "ap-northeast-2"
      "vpcId"                 = data.terraform_remote_state.terraform_state.outputs.seoul_vpc_id
      "image.repository"      = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller"
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.lb_controller_role.iam_role_arn
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}


module "EFS_Driver_Role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role = true

  role_name        = local.efs_controller_iam_role_name
  role_path        = "/"
  role_description = "Used by EFS Driver Role for EKS"

  role_permissions_boundary_arn = ""

  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:${local.efs_controller_service_account_name}"
  ]
  oidc_fully_qualified_audiences = [
    "sts.amazonaws.com"
  ]
}

data "http" "iam_policy_efs" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json"
}

resource "aws_iam_role_policy" "EFS_controller" {
  name_prefix = "AmazonEKS_EFS_CSI_Driver_Policy"
  policy      = data.http.iam_policy_efs.body
  role        = module.EFS_Driver_Role.iam_role_name
}

resource "helm_release" "EFS_release" {
  name       = "aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  namespace  = "kube-system"

  
  dynamic "set" {
    for_each = {
      "clusterName"           = module.eks.cluster_name
      "serviceAccount.create" = "true"
      "serviceAccount.name"   = local.efs_controller_service_account_name
      "region"                = "ap-northeast-2"
      "vpcId"                 = data.terraform_remote_state.terraform_state.outputs.seoul_vpc_id
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.EFS_Driver_Role.iam_role_arn
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}