# Headscale Configuration - Production
# Generated from template - do not edit directly
# Run 'sudo headscale-config' to regenerate

server_url: https://${HEADSCALE_DOMAIN}
listen_addr: 127.0.0.1:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false

noise:
  private_key_path: /var/lib/headscale/noise_private.key

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential

derp:
  server:
    enabled: true
    region_id: 999
    region_code: vps
    region_name: VPS DERP
    stun_listen_addr: 0.0.0.0:3478
    private_key_path: /var/lib/headscale/derp_private.key
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update_enabled: true
  update_frequency: 24h

disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite

log:
  format: text
  level: info

dns:
  magic_dns: true
  base_domain: headscale.local
  nameservers:
    global:
      - 1.1.1.1
      - 8.8.8.8
    split: {}
  search_domains: []
  extra_records: []

# Azure AD OIDC Configuration
oidc:
  only_start_if_oidc_is_available: false
  issuer: https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0
  client_id: ${AZURE_CLIENT_ID}
  # systemd LoadCredentialEncrypted makes secrets available in $CREDENTIALS_DIRECTORY
  # Falls back to plaintext path if encrypted credentials don't exist
  client_secret_path: /run/credentials/headscale.service/oidc_client_secret
  scope:
    - openid
    - profile
    - email
  extra_params:
    prompt: select_account
  allowed_domains: []
  allowed_users:
    - ${ALLOWED_EMAIL}

# ACL Policy - using database mode for Headplane management
policy:
  mode: database