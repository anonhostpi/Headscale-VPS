# If on an environment that starts off with root instead of ubuntu/normal user:
/usr/local/bin/headscale-user-setup

# Then reconnect and do:
sudo cloud-init status --wait

# Switch to root user:
sudo su

export HEADSCALE_DOMAIN=""
export AZURE_TENANT_ID=""
export AZURE_CLIENT_ID=""
export AZURE_CLIENT_SECRET=""
export ALLOWED_EMAIL=""

/usr/local/bin/headscale-config

# SMTP login:
export SMTP_SENDER_EMAIL=""
export SMTP_PASSWORD=""

# SMTP email headers:
export SMTP_FROM_EMAIL=""
export SMTP_RECIPIENT_EMAIL=""

echo -n "${SMTP_PASSWORD}" > /etc/msmtp-password
chmod 600 /etc/msmtp-password
sed -i "s|^from.*|from           ${SMTP_FROM_EMAIL}|" /etc/msmtprc
sed -i "s|^user.*|user           ${SMTP_SENDER_EMAIL}|" /etc/msmtprc
chmod 600 /etc/msmtprc
printf 'root: %s\nheadscale: %s\ndefault: %s\n' "$SMTP_RECIPIENT_EMAIL" "$SMTP_RECIPIENT_EMAIL" "$SMTP_RECIPIENT_EMAIL" >> /etc/aliases
