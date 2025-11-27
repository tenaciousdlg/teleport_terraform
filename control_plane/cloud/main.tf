##################################################################################
# CONFIGURATION - Terraform
##################################################################################
terraform {
  required_providers {
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "~> 18.0"
    }
  }
}

##################################################################################
# PROVIDERS
##################################################################################
provider "teleport" {
  addr = "${var.proxy_address}:443"
}

##################################################################################
# SAML CONNECTOR
##################################################################################

resource "teleport_saml_connector" "okta" {
  version = "v2"

  # Ensure all mapped roles exist before updating the connector
  depends_on = [
    teleport_role.base_user,
    teleport_role.dev_environment_access,
    teleport_role.prod_readonly_access,
    teleport_role.prod_full_access,
    teleport_role.engineering_tools_access,
    teleport_role.prod_access_requester,
    teleport_role.access_reviewer,
  ]

  metadata = {
    name = "okta"
  }

  # Keep SAML fairly minimal and let Access Lists & traits do the heavy lifting
  spec = {
    attributes_to_roles = [
      # Everyone who authenticates gets the base-user role
      {
        name  = "groups"
        value = "Everyone"
        roles = [
          "base-user"
        ]
      },
      # Engineering org – daily dev + tools + can request prod read-only
      {
        name  = "groups"
        value = "engineers"
        roles = [
          "base-user",
          "dev-environment-access",
          "engineering-tools-access",
          "prod-access-requester",
          "access-reviewer"
        ]
      },
      # Devs subset – same as engineers (you can tighten later if desired)
      {
        name  = "groups"
        value = "devs"
        roles = [
          "base-user",
          "dev-environment-access",
          "engineering-tools-access",
          "prod-access-requester"
        ]
      }
    ]

    acs                     = "https://${var.proxy_address}/v1/webapi/saml/acs/okta"
    entity_descriptor_url   = var.okta_metadata_url
    service_provider_issuer = "https://${var.proxy_address}/sso/saml/metadata"
  }
}

##################################################################################
# AUTH PREFERENCE
##################################################################################

resource "teleport_auth_preference" "main" {
  depends_on = [teleport_saml_connector.okta]

  version = "v2"

  metadata = {
    description = "auth preference"
    labels = {
      name                  = "cluster-auth-preference"
      "teleport.dev/origin" = "dynamic"
    }
  }

  spec = {
    type          = "saml"
    second_factor = "on"

    webauthn = {
      rp_id = var.proxy_address
    }

    connector_name     = teleport_saml_connector.okta.metadata.name
    allow_local_auth   = true
    allow_passwordless = true
  }
}

##################################################################################
# BASE ROLES
##################################################################################

# Base role with minimal permissions - used as a foundation for Access Lists
resource "teleport_role" "base_user" {
  version = "v7"

  metadata = {
    name        = "base-user"
    description = "Base authenticated user with minimal permissions"
  }

  spec = {
    options = {
      max_session_ttl    = "8h0m0s"
      enhanced_recording = ["command", "network"]
    }

    allow = {
      rules = [
        {
          resources = ["event"]
          verbs     = ["list", "read"]
        },
        {
          resources = ["session"]
          verbs     = ["read", "list"]
        }
      ]
    }
  }
}

##################################################################################
# GRANULAR PERMISSION ROLES
##################################################################################

# Development Environment Access
resource "teleport_role" "dev_environment_access" {
  version = "v7"
  metadata = {
    name        = "dev-environment-access"
    description = "Access to development tier resources"
  }

  spec = {
    allow = {
      # Application access
      app_labels = {
        tier = ["dev"]
        team = ["engineering"]
      }

      aws_role_arns = ["{{external.aws_dev_roles}}"]

      # Database access - mapped users
      db_labels = {
        tier = ["dev"]
        team = ["engineering"]
      }
      db_names = ["*"]
      db_users = ["{{external.db_users}}", "reader", "dev_user"]

      # Kubernetes access
      kubernetes_labels = {
        tier = ["dev"]
        team = ["engineering"]
      }
      kubernetes_groups = ["dev-users"]
      kubernetes_resources = [
        {
          kind      = "*"
          name      = "*"
          namespace = "dev"
          verbs     = ["get", "list", "watch", "create", "update", "patch", "delete"]
        }
      ]

      # Server access
      node_labels = {
        tier = ["dev"]
        team = ["engineering"]
      }
      logins = ["{{external.logins}}", "{{email.local(external.username)}}", "developer"]

      # Windows desktop access
      windows_desktop_labels = {
        tier = ["dev"]
        team = ["engineering"]
      }
      windows_desktop_logins = ["{{external.windows_logins}}", "DevUser"]
    }

    options = {
      max_session_ttl                = "8h0m0s"
      create_host_user_mode          = 3 # 3 = keep
      create_host_user_default_shell = "/bin/bash"

      # Disable DB auto-provisioning for this role
      create_db_user      = false
      create_db_user_mode = 1 # 1 = off

      desktop_clipboard         = true
      desktop_directory_sharing = true
      enhanced_recording        = ["command", "network"]
      pin_source_ip             = false
    }
  }
}

# Production Read-Only Access
resource "teleport_role" "prod_readonly_access" {
  version = "v7"
  metadata = {
    name        = "prod-readonly-access"
    description = "Read-only access to production resources"
  }

  spec = {
    allow = {
      app_labels = {
        tier = ["prod"]
        team = ["engineering"]
      }

      db_labels = {
        tier = ["prod"]
        team = ["engineering"]
      }
      db_names = ["*"]
      db_users = ["reader", "reporting", "{{external.readonly_db_user}}"]

      kubernetes_labels = {
        tier = ["prod"]
        team = ["engineering"]
      }
      kubernetes_groups = ["prod-viewers"]
      kubernetes_resources = [
        {
          kind      = "*"
          name      = "*"
          namespace = "prod"
          verbs     = ["get", "list", "watch"]
        }
      ]

      node_labels = {
        tier = ["prod"]
        team = ["engineering"]
      }
      logins = ["readonly", "{{external.readonly_login}}"]
    }

    options = {
      max_session_ttl       = "4h0m0s"
      create_host_user_mode = 1 # off

      # Explicitly disable DB auto-provisioning
      create_db_user      = false
      create_db_user_mode = 1 # off

      enhanced_recording = ["command", "network"]
    }
  }
}

# Production Full Access
resource "teleport_role" "prod_full_access" {
  version = "v7"
  metadata = {
    name        = "prod-full-access"
    description = "Full access to production resources"
  }

  spec = {
    allow = {
      # Application access
      app_labels = {
        tier = ["prod"]
      }

      # Database access - all users
      db_labels = {
        tier = ["prod"]
      }
      db_names = ["*"]
      db_users = ["{{external.db_users}}", "admin", "writer", "reader"]

      # Kubernetes access - full
      kubernetes_labels = {
        tier = ["prod"]
      }
      kubernetes_groups = ["system:masters", "prod-admins"]
      kubernetes_resources = [
        {
          kind      = "*"
          name      = "*"
          namespace = "*"
          verbs     = ["*"]
        }
      ]

      # Server access
      node_labels = {
        tier = ["prod"]
      }
      logins = ["{{external.logins}}", "root", "admin", "ec2-user", "ubuntu"]

      # Windows desktop access
      windows_desktop_labels = {
        tier = ["prod"]
      }
      windows_desktop_logins = ["{{external.windows_logins}}", "Administrator"]
    }

    options = {
      max_session_ttl       = "2h0m0s" # shorter for prod
      create_host_user_mode = 3        # keep

      # Explicitly disable DB auto-provisioning for prod
      create_db_user      = false
      create_db_user_mode = 1 # off

      desktop_clipboard         = true
      desktop_directory_sharing = true
      enhanced_recording        = ["command", "network"]

      # Require MFA for prod sessions
      require_session_mfa = 1 # 1 = SESSION
    }
  }
}

# Engineering Tools Access
resource "teleport_role" "engineering_tools_access" {
  version = "v7"

  metadata = {
    name        = "engineering-tools-access"
    description = "Access to engineering team tools"
  }

  spec = {
    allow = {
      app_labels = {
        team = ["engineering"]
      }
      db_labels = {
        team = ["engineering"]
      }
      db_names = ["*"]
      db_users = ["{{external.db_users}}", "engineer"]
    }

    options = {
      max_session_ttl = "8h0m0s"
    }
  }
}

##################################################################################
# ACCESS LISTS - TEAM STRUCTURE
##################################################################################

resource "teleport_access_list" "engineering_team" {
  header = {
    version = "v1"
    metadata = {
      name = "engineering-team"
    }
  }

  spec = {
    title       = "Engineering Team"
    description = "All members of the engineering organization"

    owners = [
      {
        name        = "admin"
        description = "Platform team admin"
      }
    ]

    membership_requires = {
      roles = ["base-user"]
      traits = [
        {
          key    = "groups"
          values = ["engineers", "devs", "sre", "platform"]
        }
      ]
    }

    ownership_requires = {
      traits = [
        {
          key    = "groups"
          values = ["engineering-managers", "senior-engineers"]
        }
      ]
    }

    grants = {
      roles = [
        "base-user",
        "engineering-tools-access"
      ]
    }

    audit = {
      recurrence = {
        frequency    = 3 # Every 3 months
        day_of_month = 1
      }
    }
  }
}

##################################################################################
# ACCESS LISTS - ENVIRONMENT ACCESS
##################################################################################

# Development Access List (static/terraform-managed membership)
resource "teleport_access_list" "dev_environment" {
  header = {
    version = "v1"
    metadata = {
      name = "dev-environment-access"
    }
  }

  spec = {
    title       = "Development Environment Access"
    description = "Access to development tier resources for daily work"
    type        = "static"

    owners = [
      {
        name        = "admin"
        description = "Platform team admin"
      }
    ]

    grants = {
      roles = [
        teleport_role.dev_environment_access.metadata.name
      ]
    }
  }
}

# Add engineering team to dev access via nested Access List membership
resource "teleport_access_list_member" "dev_access_engineering" {
  header = {
    version = "v1"
    metadata = {
      name = teleport_access_list.engineering_team.id
    }
  }

  spec = {
    access_list     = teleport_access_list.dev_environment.id
    membership_kind = 2 # list membership
  }
}

# Production Read-Only Access List
resource "teleport_access_list" "prod_readonly" {
  header = {
    version = "v1"
    metadata = {
      name = "prod-readonly-access"
    }
  }

  spec = {
    title       = "Production Read-Only Access"
    description = "Read-only access to production for troubleshooting"

    owners = [
      {
        name        = "admin"
        description = "Platform team admin"
      },
      {
        name            = teleport_access_list.engineering_team.id
        membership_kind = 2
        description     = "Engineering team managers"
      }
    ]

    membership_requires = {
      traits = [
        {
          key    = "groups"
          values = ["engineers", "devs"]
        }
      ]
    }

    grants = {
      roles = [
        teleport_role.prod_readonly_access.metadata.name
      ]
      traits = [
        {
          key    = "readonly_db_user"
          values = ["reporting"]
        },
        {
          key    = "readonly_login"
          values = ["viewer"]
        }
      ]
    }

    audit = {
      recurrence = {
        frequency    = 1 # monthly review
        day_of_month = 1
      }
    }
  }
}

# Production Full Access List (On-call)
resource "teleport_access_list" "prod_oncall" {
  header = {
    version = "v1"
    metadata = {
      name = "prod-oncall-access"
    }
  }

  spec = {
    title       = "Production On-Call Access"
    description = "Full production access for on-call engineers. Auto-expires after rotation."

    owners = [
      {
        name        = "admin"
        description = "Platform team admin"
      }
    ]

    membership_requires = {
      roles = ["base-user"]
      traits = [
        {
          key    = "groups"
          values = ["engineers"]
        }
      ]
    }

    grants = {
      roles = [
        teleport_role.prod_full_access.metadata.name
      ]
    }

    audit = {
      recurrence = {
        frequency    = 1 # every 1 month
        day_of_month = 1 # on the 1st
      }
      notifications = {
        start = "72h"
      }
    }
  }
}

# Break-Glass Emergency Access
resource "teleport_access_list" "break_glass" {
  header = {
    version = "v1"
    metadata = {
      name = "break-glass-emergency"
    }
  }

  spec = {
    title       = "Break-Glass Emergency Access"
    description = "Emergency access for critical incidents. All usage is audited."

    owners = [
      {
        name        = "admin"
        description = "Security team"
      }
    ]

    membership_requires = {
      traits = [
        {
          key    = "groups"
          values = ["senior-engineers", "security-team"]
        }
      ]
    }

    grants = {
      roles = [
        "access",
        "editor",
        teleport_role.prod_full_access.metadata.name
      ]
    }

    audit = {
      recurrence = {
        frequency    = 1
        day_of_month = 15
      }
    }
  }
}

##################################################################################
# ACCESS REQUEST ROLES
##################################################################################

# Requester for temporary production access
resource "teleport_role" "prod_access_requester" {
  version = "v7"

  metadata = {
    name        = "prod-access-requester"
    description = "Can request temporary production access"
  }

  spec = {
    allow = {
      request = {
        # Can request prod-readonly-access via JIT
        roles           = [teleport_role.prod_readonly_access.metadata.name]
        search_as_roles = [teleport_role.prod_readonly_access.metadata.name]
        max_duration    = "8h"

        # Require reason & ticket, but keep mapping simple here
        claims_to_roles = [
          {
            claim = "reason"
            value = "*"
            roles = [teleport_role.prod_readonly_access.metadata.name]
          }
        ]

        # Single, simple threshold that only looks at allowed fields
        thresholds = [
          {
            approve = 1
            deny    = 1
            filter  = "contains(request.roles, \"prod-readonly-access\")"
          }
        ]
      }
    }
  }
}

# Reviewer role for access requests
resource "teleport_role" "access_reviewer" {
  version = "v7"

  metadata = {
    name        = "access-reviewer"
    description = "Can review and approve access requests"
  }

  spec = {
    allow = {
      review_requests = {
        # Can review prod read-only and prod full access requests
        roles = [
          teleport_role.prod_readonly_access.metadata.name,
          teleport_role.prod_full_access.metadata.name
        ]

        # Can preview as the same roles when reviewing
        preview_as_roles = [
          teleport_role.prod_readonly_access.metadata.name,
          teleport_role.prod_full_access.metadata.name
        ]

        # No `where` expression here – the previous one used unsupported fields.
        # You can add a `where` later that only references:
        #   reviewer.roles, reviewer.traits, request.roles, request.reason, request.system_annotations
      }
    }
  }
}

##################################################################################
# OUTPUTS
##################################################################################

output "access_list_summary" {
  value = {
    team_lists = [
      teleport_access_list.engineering_team.id
    ]

    environment_lists = [
      teleport_access_list.dev_environment.id,
      teleport_access_list.prod_readonly.id,
      teleport_access_list.prod_oncall.id
    ]

    special_lists = [
      teleport_access_list.break_glass.id
    ]

    roles = [
      teleport_role.base_user.id,
      teleport_role.dev_environment_access.id,
      teleport_role.prod_readonly_access.id,
      teleport_role.prod_full_access.id,
      teleport_role.engineering_tools_access.id,
      teleport_role.prod_access_requester.id,
      teleport_role.access_reviewer.id
    ]
  }
}
