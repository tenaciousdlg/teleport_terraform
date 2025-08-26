# =====================================================
# PROVIDER CONFIGURATION
# =====================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.99"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
  }
}

# Read EKS cluster info from remote state (NO MANUAL COORDINATION)
data "terraform_remote_state" "eks" {
  backend = "local" # Change to "s3" if using remote backend
  config = {
    path = "../1-eks-cluster/terraform.tfstate"
    # For S3 backend:
    # bucket = "your-state-bucket"
    # key    = "eks-cluster/terraform.tfstate" 
    # region = var.region
  }
}

# Auto-configure providers using remote state
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "teleport.dev/creator" = var.user
      "tier"                 = "dev"
      "ManagedBy"            = "terraform"
    }
  }
}

# Auto-configure Kubernetes provider
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
    command     = "aws"
  }
}

# Auto-configure Helm provider
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
      command     = "aws"
    }
  }
}

# Auto-configure kubectl provider
provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
    command     = "aws"
  }
}

# Use cluster info from remote state
locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
}

# =====================================================
# CORE KUBERNETES RESOURCES
# =====================================================

# Create namespace

resource "kubernetes_namespace" "teleport_cluster" {
  metadata {
    name = "teleport-cluster"
    annotations = {
      "kubectl.kubernetes.io/last-applied-configuration" = ""
    }
    labels = {
      "pod-security.kubernetes.io/enforce" = "baseline"
    }
  }
}

# License secret (conditional)
resource "kubernetes_secret" "license" {
  count = fileexists("${path.module}/license.pem") ? 1 : 0

  metadata {
    name      = "license"
    namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
  }
  data = {
    "license.pem" = file("${path.module}/license.pem")
  }
  type = "Opaque"
}

# =====================================================
# AWS BACKEND INFRASTRUCTURE (DYNAMODB & S3)
# =====================================================

# DynamoDB tables for Teleport backend
resource "aws_dynamodb_table" "teleport_backend" {
  name         = "${var.proxy_address}-backend"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "HashKey"
  range_key    = "FullPath"

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "HashKey"
    type = "S"
  }

  attribute {
    name = "FullPath"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.proxy_address}-backend"
  }
}

resource "aws_dynamodb_table" "teleport_events" {
  name         = "${var.proxy_address}-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "SessionID"
  range_key    = "EventIndex"

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "SessionID"
    type = "S"
  }

  attribute {
    name = "EventIndex"
    type = "N"
  }

  attribute {
    name = "CreatedAtDate"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "N"
  }

  global_secondary_index {
    name            = "timesearch"
    hash_key        = "CreatedAtDate"
    range_key       = "CreatedAt"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "timesearchV2"
    hash_key        = "CreatedAtDate"
    range_key       = "CreatedAt"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    enabled        = true
    attribute_name = "Expires"
  }

  lifecycle {
    ignore_changes = [global_secondary_index]
  }

  tags = {
    Name = "${var.proxy_address}-events"
  }
}

# S3 bucket for session recordings
resource "aws_s3_bucket" "session_recordings" {
  bucket        = "${var.proxy_address}-session-recordings-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags = {
    Name = "${var.proxy_address}-session-recordings"
  }
}

resource "aws_s3_bucket_versioning" "session_recordings" {
  bucket = aws_s3_bucket.session_recordings.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "session_recordings" {
  bucket = aws_s3_bucket.session_recordings.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "session_recordings" {
  bucket = aws_s3_bucket.session_recordings.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "session_recordings" {
  bucket = aws_s3_bucket.session_recordings.id

  rule {
    id     = "expire-old-recordings"
    status = "Enabled"

    filter {} # Apply to all objects in the bucket

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365 # Adjust based on compliance requirements
    }
  }
}

# =====================================================
# IAM CONFIGURATION FOR IRSA
# =====================================================

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# IAM policy for Teleport auth service - update for multipart uploads
resource "aws_iam_policy" "teleport_auth" {
  name        = "${var.proxy_address}-auth-policy"
  description = "IAM policy for Teleport auth service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:GetItem",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:UpdateTimeToLive"
        ]
        Resource = [
          aws_dynamodb_table.teleport_backend.arn,
          "${aws_dynamodb_table.teleport_backend.arn}/stream/*",
          "${aws_dynamodb_table.teleport_backend.arn}/index/*",
          aws_dynamodb_table.teleport_events.arn,
          "${aws_dynamodb_table.teleport_events.arn}/stream/*",
          "${aws_dynamodb_table.teleport_events.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketVersioning",
          "s3:ListBucketMultipartUploads"  # FIXED: was s3:ListMultipartUploads
        ]
        Resource = [
          aws_s3_bucket.session_recordings.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:AbortMultipartUpload",         # ADDED: Required for session recordings
          "s3:ListMultipartUploadParts"     # ADDED: Required for session recordings
        ]
        Resource = [
          "${aws_s3_bucket.session_recordings.arn}/*"
        ]
      }
    ]
  })
}

# Get EKS cluster OIDC provider
data "aws_iam_openid_connect_provider" "eks" {
  arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn
}

# IAM role for Teleport auth service
resource "aws_iam_role" "teleport_auth" {
  name = "${var.proxy_address}-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = [
              "system:serviceaccount:${kubernetes_namespace.teleport_cluster.metadata[0].name}:teleport-cluster",
              "system:serviceaccount:${kubernetes_namespace.teleport_cluster.metadata[0].name}:teleport-cluster-proxy"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "teleport_auth" {
  role       = aws_iam_role.teleport_auth.name
  policy_arn = aws_iam_policy.teleport_auth.arn
}

# Service accounts are created by Helm chart when serviceAccount.create = true

# =====================================================
# TELEPORT HELM/SERVICE DEPLOYMENT
# =====================================================
resource "kubernetes_service_account" "teleport_auth" {
  metadata {
    name      = "teleport-cluster"
    namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.teleport_auth.arn
    }
  }
}

resource "kubernetes_service_account" "teleport_proxy" {
  metadata {
    name      = "teleport-cluster-proxy"
    namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.teleport_auth.arn
    }
  }
}

resource "kubernetes_service_account" "teleport_operator" {
  metadata {
    name      = "teleport-cluster-operator"
    namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
  }
}

# Teleport Helm release 
resource "helm_release" "teleport_cluster" {
  name       = "teleport-cluster"
  namespace  = kubernetes_namespace.teleport_cluster.metadata[0].name
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = var.teleport_version
  wait       = true
  timeout    = 300

  values = [
    jsonencode({
      clusterName       = var.proxy_address
      proxyListenerMode = "multiplex"
      acme              = true
      acmeEmail         = var.user
      enterprise        = fileexists("${path.module}/license.pem")
      labels = {
        tier = "dev"
      }
      operator = {
        enabled = true
      }
      authentication = {
        type = "saml"
      }
      serviceAccount = {
        create = false
        name   = "teleport-cluster"
      }
      auth = {
        serviceAccount = {
          create = false
          name   = "teleport-cluster"
        }
      }
      proxy = {
        serviceAccount = {
          create = false
          name   = "teleport-cluster-proxy"
        }
      }
      operator = {
        enabled = true
        serviceAccount = {
          create = false
          name   = "teleport-cluster-operator"
        }
      }
      chartMode = "aws"
      aws = {
        region                 = var.region
        backendTable           = aws_dynamodb_table.teleport_backend.name
        auditLogTable          = aws_dynamodb_table.teleport_events.name
        auditLogMirrorOnStdout = false
        dynamoAutoScaling      = false
        sessionRecordingBucket = aws_s3_bucket.session_recordings.bucket
      }
    })
  ]
  depends_on = [
    kubernetes_secret.license,
    kubernetes_service_account.teleport_auth,
    kubernetes_service_account.teleport_proxy,
    kubernetes_service_account.teleport_operator,
    aws_iam_role_policy_attachment.teleport_auth,
    aws_dynamodb_table.teleport_backend,
    aws_dynamodb_table.teleport_events,
    aws_s3_bucket.session_recordings
  ]
}

# Wait for operator to be ready
resource "time_sleep" "wait_for_operator" {
  depends_on      = [helm_release.teleport_cluster]
  create_duration = "60s"
}

# =====================================================
# TELEPORT CLUSTER RESOURCES (CRDs)
# =====================================================

# SAML Connectors
resource "kubectl_manifest" "saml_connector_okta" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v2"
    kind       = "TeleportSAMLConnector"
    metadata = {
      name      = "okta-dlg"
      namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    }
    spec = {
      acs = "https://${var.proxy_address}:443/v1/webapi/saml/acs/okta"
      attributes_to_roles = [
        { name = "groups", value = "engineers", roles = ["auditor", "dev-access", "dev-auto-access", "editor", "group-access", "prod-reviewer", "prod-access", "prod-auto-access"] },
        { name = "groups", value = "devs", roles = ["dev-access", "dev-auto-access", "prod-requester"] }
      ]
      display                 = "okta dlg"
      entity_descriptor_url   = var.okta_metadata_url
      service_provider_issuer = "https://${var.proxy_address}/sso/saml/metadata"
    }
  })
}

resource "kubectl_manifest" "saml_connector_okta_preview" {
  count      = var.enable_okta_preview ? 1 : 0
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v2"
    kind       = "TeleportSAMLConnector"
    metadata = {
      name      = "okta-preview"
      namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    }
    spec = {
      acs = "https://${var.proxy_address}/v1/webapi/saml/acs/okta-preview"
      attributes_to_roles = [
        { name = "groups", value = "Solutions-Engineering", roles = ["auditor", "access", "editor"] }
      ]
      display                 = "okta preview"
      entity_descriptor_url   = var.okta_preview_metadata_url
      service_provider_issuer = "https://${var.proxy_address}/sso/saml/metadata"
    }
  })
}

# Login Rules
resource "kubectl_manifest" "login_rule_okta" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportLoginRule"
    metadata = {
      name      = "okta-preferred-login-rule"
      namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    }
    spec = {
      priority = 0
      traits_map = {
        logins = [
          "external.logins",
          "strings.lower(external.username)"
        ]
        groups = ["external.groups"]
      }
      traits_expression = <<-EOT
        external.put("logins",
          choose(
            option(external.groups.contains("okta"), "okta"),
            option(true, "local")
          )
        )
      EOT
    }
  })
}

# Dev Access Role - For MAPPED USER databases (self-hosted MySQL, PostgreSQL, MongoDB)
resource "kubectl_manifest" "role_dev_access" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportRoleV7"
    metadata = {
      name        = "dev-access"
      namespace   = kubernetes_namespace.teleport_cluster.metadata[0].name
      description = "Development access for mapped user databases and infrastructure"
    }
    spec = {
      allow = {
        app_labels = {
          tier = ["dev"]
          team = ["engineering"]
        }
        aws_role_arns = ["{{external.aws_role_arns}}"]

        # Database access for MAPPED USERS (self-hosted databases)
        db_labels = {
          tier = ["dev"]
          team = ["engineering"]
         "teleport.dev/db-access" = ["mapped"]
        }
        # For mapped user databases, users connect as pre-existing database users
        db_names = ["{{external.db_names}}", "*"]
        db_users = ["{{external.db_users}}", "reader", "writer"] # Map to existing users
        # db_roles not needed for mapped user access

        desktop_groups = ["Administrators"]
        impersonate = {
          users = ["Db"]
          roles = ["Db"]
        }
        join_sessions = [
          {
            kinds = ["k8s", "ssh"]
            modes = ["moderator", "observer"]
            name  = "Join dev sessions"
            roles = ["dev-access", "dev-auto-access"]
          }
        ]
        kubernetes_groups = ["{{external.kubernetes_groups}}", "system:masters"]
        kubernetes_labels = {
          tier = "dev"
          team = "engineering"
        }
        kubernetes_resources = [
          { kind = "*", name = "*", namespace = "dev", verbs = ["*"] }
        ]
        logins = [
          "{{external.logins}}",
          "{{email.local(external.username)}}",
          "{{email.local(external.email)}}"
        ]
        node_labels = {
          tier = ["dev"]
          team = ["engineering"]
        }
        rules = [
          { resources = ["event"], verbs = ["list", "read"] },
          { resources = ["session"], verbs = ["read", "list"] }
        ]
        windows_desktop_labels = {
          tier = ["dev"]
          team = ["engineering"]
        }
        windows_desktop_logins = [
          "{{external.windows_logins}}",
          "{{email.local(external.username)}}"
        ]
      }
      options = {
        create_db_user                 = false
        create_desktop_user            = false
        create_host_user_mode          = "keep"
        create_host_user_default_shell = "/bin/bash"
        desktop_clipboard              = true
        desktop_directory_sharing      = true
        max_session_ttl                = "8h0m0s"
        pin_source_ip                  = false
        enhanced_recording             = ["command", "network"]
      }
    }
  })
}

# Dev Auto Access Role - For AUTO USER PROVISIONING databases (RDS)
resource "kubectl_manifest" "role_dev_auto_access" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportRoleV7"
    metadata = {
      name        = "dev-auto-access"
      namespace   = kubernetes_namespace.teleport_cluster.metadata[0].name
      description = "Development access for auto user provisioning databases (RDS)"
    }
    spec = {
      allow = {
        # Same infrastructure access as regular dev-access
        app_labels = {
          tier = ["dev"]
          team = ["engineering"]
        }
        aws_role_arns = ["{{external.aws_role_arns}}"]

        # Database access for AUTO USER PROVISIONING
        db_labels = {
          tier = ["dev"]
          team = ["engineering"]
          "teleport.dev/db-access" = ["auto"]
        }
        db_names = ["{{external.db_names}}", "*"]
        # For auto user provisioning, specify database ROLES that will be granted
        db_roles = ["{{external.db_roles}}", "reader", "writer", "dbadmin"]
        # db_users will be auto-created based on the Teleport username

        desktop_groups = ["Administrators"]
        join_sessions = [
          {
            kinds = ["k8s", "ssh"]
            modes = ["moderator", "observer"]
            name  = "Join dev sessions"
            roles = ["dev-access", "dev-auto-access"]
          }
        ]
        kubernetes_groups = ["{{external.kubernetes_groups}}", "system:masters"]
        kubernetes_labels = {
          tier = "dev"
          team = "engineering"
        }
        kubernetes_resources = [
          { kind = "*", name = "*", namespace = "dev", verbs = ["*"] }
        ]
        logins = [
          "{{external.logins}}",
          "{{email.local(external.username)}}",
          "{{email.local(external.email)}}"
        ]
        node_labels = {
          tier = ["dev"]
          team = ["engineering"]
        }
        rules = [
          { resources = ["event"], verbs = ["list", "read"] },
          { resources = ["session"], verbs = ["read", "list"] }
        ]
        windows_desktop_labels = {
          tier = ["dev"]
          team = ["engineering"]
        }
        windows_desktop_logins = [
          "{{external.windows_logins}}",
          "{{email.local(external.username)}}"
        ]
      }
      options = {
        # Auto user provisioning mode
        create_db_user                 = true
        create_db_user_mode            = "keep" # or "best_effort_drop"
        create_desktop_user            = true
        create_host_user_mode          = "keep"
        create_host_user_default_shell = "/bin/bash"
        desktop_clipboard              = true
        desktop_directory_sharing      = true
        max_session_ttl                = "8h0m0s"
        pin_source_ip                  = false
        enhanced_recording             = ["command", "network"]
      }
    }
  })
}

# Prod Access Role - For MAPPED USER databases
resource "kubectl_manifest" "role_prod_access" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportRoleV7"
    metadata = {
      name        = "prod-access"
      namespace   = kubernetes_namespace.teleport_cluster.metadata[0].name
      description = "Production access for mapped user databases and infrastructure"
    }
    spec = {
      allow = {
        app_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
        }
        aws_role_arns = ["{{external.aws_role_arns}}"]

        # Database access for MAPPED USERS
        db_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
         "teleport.dev/db-access" = ["mapped"]
        }
        db_names = ["{{external.db_names}}", "*"]
        db_users = ["{{external.db_users}}", "reader", "writer"] # Map to existing users

        desktop_groups = ["Administrators"]
        impersonate = {
          users = ["Db"]
          roles = ["Db"]
        }
        join_sessions = [
          {
            kinds = ["k8s", "ssh"]
            modes = ["moderator", "observer"]
            name  = "Join prod sessions"
            roles = ["*"]
          }
        ]
        kubernetes_groups = ["{{external.kubernetes_groups}}", "system:masters"]
        kubernetes_labels = { "*" = "*" }
        kubernetes_resources = [
          { kind = "*", name = "*", namespace = "prod", verbs = ["*"] }
        ]
        logins = [
          "{{external.logins}}",
          "{{email.local(external.username)}}",
          "{{email.local(external.email)}}",
          "ubuntu", "ec2-user"
        ]
        node_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
        }
        rules = [
          { resources = ["event"], verbs = ["list", "read"] },
          { resources = ["session"], verbs = ["read", "list"] }
        ]
        windows_desktop_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
        }
        windows_desktop_logins = [
          "{{external.windows_logins}}",
          "{{email.local(external.username)}}",
          "Administrator"
        ]
      }
      options = {
        create_db_user                 = false # Mapped user mode
        create_desktop_user            = false
        create_host_user_mode          = "keep"
        create_host_user_default_shell = "/bin/bash"
        desktop_clipboard              = true
        desktop_directory_sharing      = true
        max_session_ttl                = "2h0m0s"
        pin_source_ip                  = false
        enhanced_recording             = ["command", "network"]
      }
    }
  })
}

# Prod Auto Access Role - For AUTO USER PROVISIONING databases
resource "kubectl_manifest" "role_prod_auto_access" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportRoleV7"
    metadata = {
      name        = "prod-auto-access"
      namespace   = kubernetes_namespace.teleport_cluster.metadata[0].name
      description = "Production access for auto user provisioning databases (RDS)"
    }
    spec = {
      allow = {
        app_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
        }
        aws_role_arns = ["{{external.aws_role_arns}}"]

        # Database access for AUTO USER PROVISIONING
        db_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
          "teleport.dev/db-access" = ["auto"]
        }
        db_names = ["{{external.db_names}}", "*"]
        db_roles = ["{{external.db_roles}}", "reader", "writer", "dbadmin"]

        desktop_groups = ["Administrators"]
        join_sessions = [
          {
            kinds = ["k8s", "ssh"]
            modes = ["moderator", "observer"]
            name  = "Join prod sessions"
            roles = ["*"]
          }
        ]
        kubernetes_groups = ["{{external.kubernetes_groups}}", "system:masters"]
        kubernetes_labels = { "*" = "*" }
        kubernetes_resources = [
          { kind = "*", name = "*", namespace = "prod", verbs = ["*"] }
        ]
        logins = [
          "{{external.logins}}",
          "{{email.local(external.username)}}",
          "{{email.local(external.email)}}",
          "ubuntu", "ec2-user"
        ]
        node_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
        }
        rules = [
          { resources = ["event"], verbs = ["list", "read"] },
          { resources = ["session"], verbs = ["read", "list"] }
        ]
        windows_desktop_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
        }
        windows_desktop_logins = [
          "{{external.windows_logins}}",
          "{{email.local(external.username)}}",
          "Administrator"
        ]
      }
      options = {
        create_db_user                 = true
        create_db_user_mode            = "keep" # Auto user provisioning mode
        create_desktop_user            = true
        create_host_user_mode          = "keep"
        create_host_user_default_shell = "/bin/bash"
        desktop_clipboard              = true
        desktop_directory_sharing      = true
        max_session_ttl                = "2h0m0s"
        pin_source_ip                  = false
        enhanced_recording             = ["command", "network"]
      }
    }
  })
}

resource "kubectl_manifest" "role_prod_reviewer" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportRoleV7"
    metadata = {
      name      = "prod-reviewer"
      namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    }
    spec = {
      allow = {
        review_requests = {
          preview_as_roles = ["access", "prod-access", "prod-auto-access"]
          roles            = ["access", "prod-access", "prod-auto-access"]
        }
      }
    }
  })
}

resource "kubectl_manifest" "role_prod_requester" {
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportRoleV7"
    metadata = {
      name      = "prod-requester"
      namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    }
    spec = {
      allow = {
        request = {
          roles           = ["prod-access", "prod-auto-access"]
          search_as_roles = ["access", "prod-access"]
        }
      }
    }
  })
}

# Access Lists 
# Note: Access list CRD may not be available in all Teleport versions
# If this fails, remove this resource and apply access lists manually
resource "kubectl_manifest" "access_list_support_engineers" {
  count      = var.enable_access_lists ? 1 : 0
  depends_on = [time_sleep.wait_for_operator]

  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v1"
    kind       = "TeleportAccessList"
    metadata = {
      name      = "support-engineers"
      namespace = kubernetes_namespace.teleport_cluster.metadata[0].name
    }
    spec = {
      title       = "Production access for support engineers"
      description = "Use this Access List to grant access to production to your engineers enrolled in the support rotation."
      audit = {
        recurrence = {
          frequency = "6months"
        }
      }
      owners = [
        {
          description = "manager of NA support team"
          name        = "alice"
        }
      ]
      ownership_requires = {
        roles = ["manager"]
      }
      grants = {
        roles = ["dev-access", "dev-auto-access"]
      }
      membership_requires = {
        roles = ["engineer"]
      }
    }
  })
}

# =====================================================
# DNS AND NETWORKING
# =====================================================

# Get service info for DNS
data "kubernetes_service" "teleport_cluster" {
  depends_on = [helm_release.teleport_cluster]

  metadata {
    name      = helm_release.teleport_cluster.name
    namespace = helm_release.teleport_cluster.namespace
  }
}

# Route53 DNS records (conditional)
data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

resource "aws_route53_record" "cluster_endpoint" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.proxy_address
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}

resource "aws_route53_record" "wild_cluster_endpoint" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "*.${var.proxy_address}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname]
}

# =====================================================
# OUTPUTS
# =====================================================

output "teleport_url" {
  description = "Teleport demo URL"
  value       = var.domain_name != "" ? "https://${var.proxy_address}" : "https://${try(data.kubernetes_service.teleport_cluster.status[0].load_balancer[0].ingress[0].hostname, "pending")}"
}

output "teleport_version" {
  description = "Deployed Teleport version"
  value       = var.teleport_version
}

output "cluster_name" {
  description = "Teleport cluster name"
  value       = var.proxy_address
}

output "eks_cluster_name" {
  description = "EKS cluster name from remote state"
  value       = local.cluster_name
}

output "dynamodb_backend_table" {
  description = "DynamoDB backend table name"
  value       = aws_dynamodb_table.teleport_backend.name
}

output "dynamodb_events_table" {
  description = "DynamoDB events table name"
  value       = aws_dynamodb_table.teleport_events.name
}

output "s3_session_recordings_bucket" {
  description = "S3 bucket for session recordings"
  value       = aws_s3_bucket.session_recordings.id
}