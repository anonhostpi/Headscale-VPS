# msmtp Email Notification Setup

Complete guide for configuring email notifications for Headscale system alerts using msmtp and Microsoft 365.

## Overview

This deployment can optionally send email notifications for system events using:
- **msmtp** - Lightweight SMTP client for sending email
- **Microsoft 365** - SMTP relay for reliable email delivery

Email notifications are sent for:
- System security events (fail2ban alerts)
- Service failures or restarts
- Certificate renewal issues
- System updates requiring attention

---

## Prerequisites

- Microsoft 365 account (personal or organizational)
- Account must have Multi-Factor Authentication (MFA) enabled
  - Required for App Password creation
  - If MFA is not enabled, you must enable it first

---

## Part 1: Create M365 App Password

### Step 1: Navigate to Security Settings

1. Sign in to your Microsoft account: https://account.microsoft.com/
   - Or for organizational accounts: https://myaccount.microsoft.com/
2. Navigate to **Security** → **Security info**
   - Direct link: https://mysignins.microsoft.com/security-info
3. Ensure MFA is enabled (you should see authentication methods listed)

### Step 2: Create App Password

1. Click **Add sign-in method** (or **Add method**)
2. Select **App password** from the dropdown
3. Click **Add**
4. Enter a name for the app password:
   - Example: `Headscale VPS Notifications`
   - This helps you identify it later for rotation/revocation
5. Click **Next** or **Generate**

### Step 3: Copy App Password

1. **⚠️ CRITICAL**: Copy the generated password immediately
   - Format: 16 characters (e.g., `abcd efgh ijkl mnop` or `abcdefghijklmnop`)
   - This is shown only once - you cannot retrieve it later
   - Store it securely until you complete configuration
2. Click **Done**

**Note**: The spaces in the password are for readability only - you can include or omit them when configuring.

---

## Part 2: Deployment Configuration

### Option A: During Initial Deployment

When running `Deploy-Headscale.ps1` without a config file, you'll be prompted for optional SMTP settings:

1. Run the deployment script:
   ```powershell
   .\Deploy-Headscale.ps1
   ```

2. After entering required parameters, you'll see optional prompts:
   ```
   SMTP Sender Email (M365 email for notifications): admin@contoso.com
   SMTP Recipient Email (where alerts are sent): admin@contoso.com
   SMTP App Password (from M365): [paste app password - hidden]
   ```

3. Enter your values:
   - **Sender Email**: Your M365 email address (e.g., `admin@contoso.com`)
   - **Recipient Email**: Where alerts should be sent (can be same as sender, or different)
   - **App Password**: Paste the password from Part 1, Step 3

4. Press Enter on any optional field to skip email notifications

### Option B: Using Configuration File

Add these fields to your `config.json`:

```json
{
  "Network": "Ethernet 3",
  "NgrokToken": "your_ngrok_token",
  "Domain": "your-domain.ngrok-free.dev",
  "AzureTenantID": "your_tenant_id",
  "AzureClientID": "your_client_id",
  "AzureClientSecret": "your_client_secret",
  "AzureAllowedEmail": "admin@contoso.com",
  "SmtpSenderEmail": "admin@contoso.com",
  "SmtpRecipientEmail": "admin@contoso.com",
  "SmtpPassword": "your_app_password_here"
}
```

Then run deployment:
```powershell
.\Deploy-Headscale.ps1 -ConfigFile config.json
```

### Option C: Skip Email Notifications

Email notifications are **completely optional**. To skip:
- Leave SMTP fields blank when prompted, OR
- Omit SMTP fields from config.json

The deployment will show:
```
========================================
  Email Notifications
========================================

⊘ Skipped - SMTP not configured
  To enable: Add SmtpSenderEmail, SmtpRecipientEmail, SmtpPassword to config
```

---

## Part 3: Verify Configuration

### Check msmtp Configuration

After deployment completes, verify msmtp is configured:

```bash
multipass exec headscale-test -- sudo cat /etc/msmtprc
```

Expected output:
```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        microsoft
host           smtp.office365.com
port           587
from           admin@contoso.com
user           admin@contoso.com
passwordeval   cat /etc/msmtp-password

account default : microsoft
```

### Check Email Aliases

Verify mail routing is configured:

```bash
multipass exec headscale-test -- sudo cat /etc/aliases
```

Expected output:
```
root: admin@contoso.com
headscale: admin@contoso.com
default: admin@contoso.com
```

---

## Part 4: Test Email Notifications

### Test 1: Manual Email Send

Send a test email from the VM:

```bash
multipass exec headscale-test -- bash -c "echo 'Test email from Headscale VM' | mail -s 'Test Subject' root"
```

**Expected Result**:
- Email delivered to recipient address within 1-2 minutes
- Check spam folder if not received

### Test 2: Check Email Logs

View msmtp logs to verify sending:

```bash
multipass exec headscale-test -- sudo tail -n 20 /var/log/msmtp.log
```

Expected output for successful send:
```
Dec 27 10:30:15 host=smtp.office365.com tls=on auth=on user=admin@contoso.com from=admin@contoso.com recipients=admin@contoso.com exitcode=EX_OK
```

### Test 3: Trigger System Alert

Trigger a fail2ban notification to test real-world scenario:

```bash
# Attempt multiple failed SSH logins to trigger fail2ban
multipass exec headscale-test -- bash -c 'for i in {1..10}; do echo "test" | sudo -S -u nonexistent ssh localhost 2>/dev/null; sleep 1; done'
```

**Expected Result**:
- After 5-10 failed attempts, fail2ban bans the IP
- Email notification sent with subject like: `[Fail2Ban] sshd: banned IP.ADDRESS`

---

## Security Best Practices

### App Password Rotation

**M365 App Passwords do not expire**, but you should rotate them periodically:

**When to Rotate:**
- Every 6-12 months (recommended)
- Immediately if exposed or compromised
- When employee leaves organization (if using organizational account)

**How to Rotate:**

1. Create new App Password in M365 (Part 1)
2. Update configuration on VM:
   ```bash
   multipass exec headscale-test -- sudo bash -c "echo -n 'NEW_APP_PASSWORD' > /etc/msmtp-password"
   ```
3. Test email sending (Part 4, Test 1)
4. Revoke old App Password:
   - Navigate to: https://mysignins.microsoft.com/security-info
   - Find old app password, click **Delete**

### App Password Revocation

To immediately revoke an App Password:

1. Go to: https://mysignins.microsoft.com/security-info
2. Find the app password by name (e.g., "Headscale VPS Notifications")
3. Click **Delete** or **Revoke**
4. Confirm revocation

**Effect**: Email notifications will stop immediately. Update configuration with new password to restore.

### Password Storage Security

The deployment stores the App Password in `/etc/msmtp-password` with:
- **Permissions**: `600` (owner read/write only)
- **Owner**: `root`
- **Encryption**: Optional systemd-creds support (available but not configured by default)

To check file permissions:
```bash
multipass exec headscale-test -- sudo ls -la /etc/msmtp-password
```

Expected output:
```
-rw------- 1 root root 16 Dec 27 10:00 /etc/msmtp-password
```

---

## Troubleshooting

### Issue: Email Not Received

**Symptoms:**
- Test email sent but not received
- No error in logs

**Solutions:**

1. **Check spam/junk folder**
   - M365 spam filters may flag system emails
   - Add sender to safe senders list

2. **Verify recipient email address**:
   ```bash
   multipass exec headscale-test -- sudo cat /etc/aliases
   ```

3. **Check msmtp logs for errors**:
   ```bash
   multipass exec headscale-test -- sudo tail -n 50 /var/log/msmtp.log
   ```

4. **Test SMTP connectivity**:
   ```bash
   multipass exec headscale-test -- telnet smtp.office365.com 587
   ```
   Expected: `220 smtp.office365.com Microsoft ESMTP MAIL Service ready`

### Issue: Authentication Failed

**Symptoms:**
- msmtp log shows: `authentication failed`
- Exit code: `EX_NOPERM` or `EX_UNAVAILABLE`

**Solutions:**

1. **Verify App Password is correct**:
   - App Passwords are case-sensitive
   - Ensure no extra spaces or newlines:
     ```bash
     multipass exec headscale-test -- sudo cat /etc/msmtp-password | wc -c
     ```
     Expected: `16` (exactly 16 characters for standard app password)

2. **Recreate App Password**:
   - Delete old App Password in M365
   - Create new one (Part 1)
   - Update on VM:
     ```bash
     multipass exec headscale-test -- sudo bash -c "echo -n 'NEW_PASSWORD' > /etc/msmtp-password"
     ```

3. **Check sender email matches**:
   ```bash
   multipass exec headscale-test -- sudo grep "from\|user" /etc/msmtprc
   ```
   Both should match your M365 email exactly

### Issue: TLS Handshake Failed

**Symptoms:**
- msmtp log shows: `TLS handshake failed`
- Connection to smtp.office365.com:587 fails

**Solutions:**

1. **Update CA certificates**:
   ```bash
   multipass exec headscale-test -- sudo apt update && sudo apt install -y ca-certificates
   ```

2. **Check system time** (TLS requires accurate time):
   ```bash
   multipass exec headscale-test -- timedatectl status
   ```
   If time is off:
   ```bash
   multipass exec headscale-test -- sudo timedatectl set-ntp true
   ```

3. **Test TLS connection manually**:
   ```bash
   multipass exec headscale-test -- openssl s_client -connect smtp.office365.com:587 -starttls smtp
   ```
   Expected: Shows certificate chain and `Verify return code: 0 (ok)`

### Issue: "Command Not Found" for mail

**Symptoms:**
- `mail: command not found` when testing

**Solution:**

The `mail` command is provided by `mailutils` package, installed during cloud-init. If missing:
```bash
multipass exec headscale-test -- sudo apt install -y mailutils
```

When prompted, select:
- **General mail configuration type**: `Internet Site`
- **System mail name**: (press Enter to use default)

### Issue: Permission Denied Reading Password File

**Symptoms:**
- msmtp log shows: `cannot read password file`
- Emails fail to send

**Solutions:**

1. **Fix file permissions**:
   ```bash
   multipass exec headscale-test -- sudo chmod 600 /etc/msmtp-password
   multipass exec headscale-test -- sudo chown root:root /etc/msmtp-password
   ```

2. **Verify msmtprc permissions**:
   ```bash
   multipass exec headscale-test -- sudo chmod 600 /etc/msmtprc
   ```

### Issue: MFA Not Enabled on M365 Account

**Symptoms:**
- Cannot find "App password" option in security settings
- Only see password and other sign-in methods

**Solution:**

Enable MFA on your Microsoft account:

1. Go to: https://mysignins.microsoft.com/security-info
2. Click **Add sign-in method**
3. Add one of:
   - **Microsoft Authenticator app** (recommended)
   - **Phone number** (SMS or call)
   - **Email** (alternate email)
4. Complete MFA setup
5. After MFA is enabled, App Password option will appear

**Note**: Some organizational accounts require admin to enable MFA. Contact your IT administrator if unavailable.

---

## Advanced Configuration

### Use Different Sender and Recipient

To send from one address but receive at another:

```json
{
  "SmtpSenderEmail": "noreply@contoso.com",
  "SmtpRecipientEmail": "alerts@contoso.com",
  "SmtpPassword": "app_password_for_noreply@contoso.com"
}
```

**Requirement**: The sender email must match the M365 account that created the App Password.

### Multiple Recipients

To send to multiple recipients, edit `/etc/aliases` on the VM:

```bash
multipass exec headscale-test -- sudo bash -c "cat > /etc/aliases << 'EOF'
root: admin@contoso.com, security@contoso.com, alerts@contoso.com
headscale: admin@contoso.com, security@contoso.com
default: admin@contoso.com
EOF"
```

**Note**: Separate addresses with commas (no spaces).

### Configure System Services to Send Email

Individual services can be configured to send notifications:

**fail2ban** (already configured):
```bash
multipass exec headscale-test -- sudo grep "destemail\|sendername" /etc/fail2ban/jail.local
```

**Headscale** (add email notifications for errors):
```bash
multipass exec headscale-test -- sudo bash -c 'cat >> /etc/systemd/system/headscale.service.d/override.conf << "EOF"

[Service]
# Send email on failure
OnFailure=email-on-failure@%n.service
EOF'
```

Then create email service:
```bash
multipass exec headscale-test -- sudo bash -c 'cat > /etc/systemd/system/email-on-failure@.service << "EOF"
[Unit]
Description=Send email notification on service failure
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'echo "Service %i has failed on $(hostname)" | mail -s "[ALERT] Service %i Failed" root'
EOF'

multipass exec headscale-test -- sudo systemctl daemon-reload
```

### Debugging with Verbose Logging

Enable verbose msmtp logging for troubleshooting:

```bash
multipass exec headscale-test -- sudo bash -c "echo 'test email' | msmtp -v --debug root"
```

This shows full SMTP session including:
- TLS handshake details
- Authentication process
- SMTP commands and responses

---

## Reference Links

- [msmtp Documentation](https://marlam.de/msmtp/)
- [Microsoft 365 SMTP Settings](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365)
- [App Passwords for Microsoft Account](https://support.microsoft.com/en-us/account-billing/manage-app-passwords-for-two-step-verification-d6dc8c6d-4bf7-4851-ad95-6d07799387e9)
- [fail2ban Email Notifications](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8#Alerts)

---

## Quick Reference Card

**Create M365 App Password:**
```
1. https://mysignins.microsoft.com/security-info
2. Add sign-in method → App password
3. Name it (e.g., "Headscale VPS")
4. Copy password immediately
```

**Configuration Fields:**
```json
{
  "SmtpSenderEmail": "your_email@contoso.com",
  "SmtpRecipientEmail": "alerts@contoso.com",
  "SmtpPassword": "your_16_char_app_password"
}
```

**Test Email:**
```bash
multipass exec headscale-test -- bash -c "echo 'Test message' | mail -s 'Test' root"
```

**Check Logs:**
```bash
multipass exec headscale-test -- sudo tail -f /var/log/msmtp.log
```

**Verify Config:**
```bash
multipass exec headscale-test -- sudo cat /etc/msmtprc
multipass exec headscale-test -- sudo cat /etc/aliases
```

**Update Password:**
```bash
multipass exec headscale-test -- sudo bash -c "echo -n 'NEW_PASSWORD' > /etc/msmtp-password"
```

**Revoke App Password:**
```
https://mysignins.microsoft.com/security-info → Delete app password
```

---

**Last Updated:** 2025-12-27
**Repository:** https://github.com/anonhostpi/Headscale-VPS
