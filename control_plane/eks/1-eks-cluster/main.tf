# defines aws provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.39"
    }
  }
}

provider "aws" {
  region = var.region
  # these are tags that are added to aws resources this config creates
  # these are optional
  default_tags {
    tags = {
      "teleport.dev/creator" = var.user
      "tier"                 = "demo"
      "ManagedBy"            = "terraform"
      name                   = var.name
    }
  }
}

# checks for space in availability zones
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# local variables used across resources
# setting a static private network config for ease of use
locals {
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

# aws vpc module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for index, az in local.azs : cidrsubnet(local.vpc_cidr, 4, index)]
  public_subnets  = [for index, az in local.azs : cidrsubnet(local.vpc_cidr, 8, index + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# aws eks module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.name}-cluster"
  cluster_version = var.ver_cluster

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    tags = {
      "teleport.dev/creator" = var.user
    }
  }

  eks_managed_node_groups = {
    one = {
      name = "${var.name}-node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "${var.name}-node-group-2"

      instance_types = ["t3.micro"]

      min_size     = 1
      max_size     = 4
      desired_size = 2
    }
  }
}

# module for configuration of eks cluster components  
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
    }
  }
}

# iam module for ebs csi driver. Needed to give eks cluster perms to create ebs for pvc used with teleport
# https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/discussions/406
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${var.name}-cluster-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}