##################################################################################
# CONFIGURATION - added for Terraform >0.14
##################################################################################
terraform {
  required_providers {
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "15.4.0"
    }
  }
}
##################################################################################
# PROVIDERS
##################################################################################
provider "teleport" {
  addr               = "${var.proxy_address}:443"
  identity_file_path = var.identity_path
}
##################################################################################
# DATA SOURCES
##################################################################################
##################################################################################
# RESOURCES
##################################################################################
resource "teleport_auth_preference" "main" {
  depends_on = [teleport_saml_connector.okta]
  version    = "v2"
  metadata = {
    description = "auth preference"
    labels = {
      name                  = "cluster-auth-preference"
      "teleport.dev/origin" = "dynamic" // This label is added on Teleport side by default and is a required arg
    }
  }
  spec = {
    type          = "saml"
    second_factor = "on"
    webauthn = {
      rp_id = "${var.proxy_address}"
    }
    connector_name     = teleport_saml_connector.okta.metadata.name
    allow_local_auth   = true
    allow_passwordless = true
  }
}

resource "teleport_role" "dev" {
  version = "v7"
  metadata = {
    name        = "dev-access"
    description = "terraform controlled Role allowing access to dev respirces"
    labels = {
      team = "dev"
      env  = "dev"
    }
  }

  spec = {
    options = {
      forward_agent           = false
      max_session_ttl         = "8h0m0s"
      port_forwarding         = false
      client_idle_timeout     = "1h"
      disconnect_expired_cert = true
      premit_x11_forwarding   = false
      request_acces           = "denied"
      enhanced_recording      = ["command", "network"]
    }

    allow = {
      logins                 = ["ubuntu", "ec2-user"]
      windows_desktop_logins = ["Administrator"]
      kubernetes_groups      = ["system:masters"] # Example group, adjust as needed
      db_users               = ["alice", "bob"]
      db_names               = ["*"] # Access to all databases, adjust as needed
      app_labels = {
        env = ["dev"]
      }
      node_labels = {
        env = ["dev"]
      }
      windows_desktop_labels = {
        env = ["dev"]
      }
      kubernetes_labels = {
        env = ["dev"]
      }
      database_labels = {
        env = ["dev"]
      }
    }

    deny = {
      logins = ["anonymous"]
    }
  }
}

resource "teleport_saml_connector" "okta" {
  version = "v2"
  # This section tells Terraform that role example must be created before the SAML connector
  depends_on = [
    teleport_role.dev
  ]

  metadata = {
    name = "okta"
  }

  spec = {
    attributes_to_roles = [{
      name  = "groups"
      roles = ["requester"]
      value = "Everyone"
      },
      {
        name  = "groups"
        roles = ["access", "editor", "reviewer", "auditor", "group-access"]
        value = "admins"
      },
      {
        name  = "groups"
        roles = ["dev-access"]
        value = "devs"
      },
      {
        name  = "groups"
        roles = ["editor"]
        value = "engineers"
      },
      {
        name  = "groups"
        roles = ["access"]
        value = "interns"
    }]

    acs                   = "https://${var.proxy_address}/v1/webapi/saml/acs/okta-integration"
    entity_descriptor_url = "https://${var.okta_sso_app}/sso/saml/metadata"
  }
}

##################################################################################
# OUTPUT
##################################################################################
##################################################################################