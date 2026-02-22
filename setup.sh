# If on an environment that starts off with root instead of ubuntu/normal user:
/usr/local/bin/relay-user-setup

# Then reconnect and do:
sudo cloud-init status --wait

# Switch to root user:
sudo su

# Option 1: Unified YAML config (recommended)
# Store config.yaml in your password manager, then pipe it:
# cat config.yaml | sudo server-config
# Or pass as file:
# sudo server-config --config /path/to/config.yaml

# Option 2: Interactive config (legacy)
/usr/local/bin/relay-config

# SMTP config (if not using server-config):
/usr/local/bin/relay-msmtp-config
