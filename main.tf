variable "auth0_domain" {}
variable "auth0_client_id" {}
variable "auth0_client_secret" {}

terraform {
  required_providers {
    auth0 = {
      source = "auth0/auth0"
      version = "0.30.2"
    }
  }
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
}

# Create API
resource "auth0_resource_server" "my_resource_server" {
  name        = "CHP Api"
  identifier  = "https://api.example.com/"
  signing_alg = "RS256"

  token_dialect = "access_token_authz"
  enforce_policies = true

  scopes {
    value       = "create:foo"
    description = "Create foos"
  }

  scopes {
    value       = "create:bar"
    description = "Create bars"
  }

  allow_offline_access                            = true
  token_lifetime                                  = 8600
}

# Create Application
resource "auth0_client" "my_client" {
  name = "Vertical Application"
  description = "Test Applications Long Description"
  app_type = "spa"

  # custom_login_page_on = true
  is_first_party = true
  is_token_endpoint_ip_header_trusted = true

  token_endpoint_auth_method = "client_secret_post"

  oidc_conformant = false

  initiate_login_uri = "https://example.com/login"
  callbacks = [ "https://example.com/callback", "http://localhost:3000/callback" ]
  web_origins = [ "https://example.com" ]
  allowed_origins = [ "https://example.com", "http://localhost:3000" ]
  allowed_clients = [ "https://allowed.example.com" ]
  allowed_logout_urls = [ "https://example.com" ]

  grant_types = [ "authorization_code", "http://auth0.com/oauth/grant-type/password-realm", "implicit", "password", "refresh_token" ]

  organization_usage = "deny"
  organization_require_behavior = "no_prompt"


  jwt_configuration {
    lifetime_in_seconds = 36000
    secret_encoded = true
    alg = "RS256"
  }

  # refresh_token {
    # rotation_type = "non-rotating"
    # expiration_type = "non-expiring"
    # leeway = 15
    # token_lifetime = 84600
    # infinite_idle_token_lifetime = false
    # infinite_token_lifetime      = false
    # idle_token_lifetime          = 1296000
  # }

  # client_secret_rotation_trigger = {
  #   triggered_at = "2018-01-02T23:12:01Z"
  #   triggered_by = "auth0"
  # }
}

# Enable M2M client on the API
resource "auth0_client_grant" "my_client_grant" {
  client_id = auth0_client.my_client.id
  audience  = auth0_resource_server.my_resource_server.identifier
  scope     = ["create:foo"]
}

# Create roles
resource "auth0_role" "my_role" {
  name = "My Role - (Managed by Terraform)"
  description = "Role Description..."

  permissions {
    resource_server_identifier = auth0_resource_server.my_resource_server.identifier
    name = "create:foo"
  }

  permissions {
    resource_server_identifier = auth0_resource_server.my_resource_server.identifier
    name = "create:bar"
  }
}

# To connect the code below with the default connection created on tenant creation run:
# $ terraform import auth0_connection.my_connection {CONN_ID}

# Configure default connection
resource "auth0_connection" "my_connection" {
  name = "Username-Password-Authentication"
  strategy = "auth0"
  enabled_clients = [auth0_client.my_client.id]

  options {
    disable_signup = true

    password_policy = "fair"
    password_history {
      enable = true
      size = 5
    }
    password_no_personal_info {
      enable = true
    }
    password_dictionary {
      enable = true
    }
    brute_force_protection = "true"
    password_complexity_options {
      min_length = 8
    }
  }
}

# Security
resource "auth0_attack_protection" "attack_protection" {
  suspicious_ip_throttling {
    enabled   = true
    shields   = ["admin_notification", "block"]
  }
  brute_force_protection {
    enabled      = true
    max_attempts = 10
    shields      = ["block", "user_notification"]
  }
  breached_password_detection {
    admin_notification_frequency = ["immediately"]
    enabled                      = true
    method                       = "enhanced"
    shields                      = ["admin_notification", "user_notification", "block"]
  }
}

# Bot detection not possible yet

# MFA
resource "auth0_guardian" "default" {
  policy = "all-applications"
  phone {
    provider      = "twilio"
    message_types = ["sms", "voice"]
    options {
      enrollment_message   = "{{code}} is your verification code for {{tenant.friendly_name}}. Please enter this code to verify your enrollment."
      verification_message = "{{code}} is your verification code for {{tenant.friendly_name}}."
      sid = ""
      auth_token = ""
      from  = ""
      # messaging_service_sid = ""
    }
  }
  email = true
  otp = true
}

# Custom domain and Universal Login
resource "auth0_custom_domain" "my_custom_domain" {
  domain = "test.falsepill.com"
  type = "self_managed_certs"
}

# resource "auth0_custom_domain_verification" "my_custom_domain_verification" {
#     custom_domain_id = auth0_custom_domain.my_custom_domain.id
#     timeouts { create = "15m" }
#     depends_on = [ {ENTER CUSTOM DOMAIN RECORD RESOURCE HERE} ]
# }

resource "auth0_branding" "my_brand" {
    logo_url = "https://cdn.auth0.com/manhattan/versions/1.3585.0/assets/badge.png"
    colors {
        primary = "#0059d6"
        page_background = "#000000"
    }
    universal_login {
        body = "<!DOCTYPE html><html><head>{%- auth0:head -%}</head><body>{%- auth0:widget -%}</body></html>"
    }
}