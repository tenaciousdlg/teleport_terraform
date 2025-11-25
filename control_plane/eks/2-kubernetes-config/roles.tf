##################################################################################
# TELEPORT CLUSTER RESOURCES (CRDs)
##################################################################################

# SAML Connectors
resource "kubectl_manifest" "saml_connector_okta" {
  depends_on = [time_sleep.wait_for_operator]
  yaml_body = yamlencode({
    apiVersion = "resources.teleport.dev/v2"
    kind       = "TeleportSAMLConnector"
    metadata = {
      name      = "okta-integrator"
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
        logins = ["external.logins", "strings.lower(external.username)"]
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

# Dev/Prod Access Roles, Reviewers, Requesters, Access Lists

##################################################################################
# DEV/PROD ACCESS ROLES (TeleportRoleV7)
##################################################################################

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
        db_labels = {
          tier = ["dev"]
          team = ["engineering"]
          "teleport.dev/db-access" = ["mapped"]
        }
        db_names = ["{{external.db_names}}", "*"]
        db_users = ["{{external.db_users}}", "reader", "writer"]
        desktop_groups = ["Administrators"]
        impersonate = {
          roles = ["Db"]
          users = ["Db"]
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
        logins = ["{{external.logins}}", "{{email.local(external.username)}}", "{{email.local(external.email)}}"]
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
        windows_desktop_logins = ["{{external.windows_logins}}", "{{email.local(external.username)}}"]
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
        app_labels = {
          tier = ["dev"]
          team = ["engineering"]
        }
        aws_role_arns = ["{{external.aws_role_arns}}"]
        db_labels = {
          tier = ["dev"]
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
        logins = ["{{external.logins}}", "{{email.local(external.username)}}", "{{email.local(external.email)}}"]
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
        windows_desktop_logins = ["{{external.windows_logins}}", "{{email.local(external.username)}}"]
      }
      options = {
        create_db_user                 = true
        create_db_user_mode            = "keep"
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
        db_labels = {
          tier = ["prod", "dev"]
          team = ["engineering"]
          "teleport.dev/db-access" = ["mapped"]
        }
        db_names = ["{{external.db_names}}", "*"]
        db_users = ["{{external.db_users}}", "reader", "writer"]
        desktop_groups = ["Administrators"]
        impersonate = {
          roles = ["Db"]
          users = ["Db"]
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
        logins = ["{{external.logins}}", "{{email.local(external.username)}}", "{{email.local(external.email)}}", "ubuntu", "ec2-user"]
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
        windows_desktop_logins = ["{{external.windows_logins}}", "{{email.local(external.username)}}", "Administrator"]
      }
      options = {
        create_db_user                 = false
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
        logins = ["{{external.logins}}", "{{email.local(external.username)}}", "{{email.local(external.email)}}", "ubuntu", "ec2-user"]
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
        windows_desktop_logins = ["{{external.windows_logins}}", "{{email.local(external.username)}}", "Administrator"]
      }
      options = {
        create_db_user                 = true
        create_db_user_mode            = "keep"
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
