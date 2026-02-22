# If on an environment that starts off with root instead of ubuntu/normal user:
/usr/local/bin/relay-user-setup

# Then reconnect and do:
sudo cloud-init status --wait

# Switch to root user:
sudo su

export HEADSCALE_DOMAIN=""
export AZURE_TENANT_ID=""
export AZURE_CLIENT_ID=""
export AZURE_CLIENT_SECRET=""
export ALLOWED_EMAIL=""

/usr/local/bin/relay-config

# SMTP config (if not using server-config):
/usr/local/bin/relay-msmtp-config
