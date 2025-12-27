# Headplane Configuration - Production
# Generated from template - do not edit directly
# Run 'sudo headscale-config' to regenerate

# NOTE: Headplane data is owned by headscale user for simplicity
# since this VPS's sole purpose is running Headscale + Headplane

server:
  host: 127.0.0.1
  port: 3000
  base_url: https://${HEADSCALE_DOMAIN}
  cookie_secret_path: /run/credentials/headplane.service/cookie_secret
  cookie_secure: true
  cookie_max_age: 86400
  data_path: /var/lib/headplane

headscale:
  url: http://127.0.0.1:8080
  public_url: https://${HEADSCALE_DOMAIN}
  config_path: /etc/headscale/config.yaml
  config_strict: false

# Azure AD OIDC Configuration
# IMPORTANT: Must use the SAME Azure App as Headscale
oidc:
  # systemd LoadCredentialEncrypted makes secrets available in $CREDENTIALS_DIRECTORY
  # Falls back to plaintext paths if encrypted credentials don't exist
  headscale_api_key_path: /run/credentials/headplane.service/headscale_api_key
  issuer: https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0
  client_id: ${AZURE_CLIENT_ID}
  client_secret_path: /run/credentials/headplane.service/oidc_client_secret
  token_endpoint_auth_method: client_secret_post
  scope: openid email profile
  disable_api_key_login: false

integration:
  proc:
    enabled: true