# defines aws provider
provider "aws" {
  region = var.region
}

# checks for space in availability zones
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# local variables used across resources
locals {
  vpc_cidr             = "10.0.0.0/16"
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    ManagedBy = "terraform"
    owner     = var.name
    env       = "dev"
  }
}

# aws vpc module; deloys vpc componets (subnets, availability zones, etc...)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name}-eks-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

# eks module 
module "eks" {
  depends_on = [module.vpc]
  source     = "terraform-aws-modules/eks/aws"
  version    = "~> 20.0"

  cluster_name    = "${var.name}-cluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2"

      instance_types = ["t3.micro"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }

  tags = local.tags
}

# module for configuration of eks cluster components  
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

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

      timeouts = {
        create = "20m"
        delete = "10m"
      }
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {

    }

  }

  tags = local.tags
}

# iam module for ebs csi driver. Needed to give eks cluster perms to create ebs 
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

  tags = local.tags
}