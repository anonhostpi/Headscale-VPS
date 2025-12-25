# Azure AD Setup for Headscale + Headplane

Complete guide for configuring Azure AD (Microsoft Entra ID) authentication for Headscale and Headplane.

## Overview

This deployment uses Azure AD OIDC for authentication in both:
- **Headscale** - For Tailscale client connections
- **Headplane** - For web UI admin access

Both services share the same Azure AD App Registration, simplifying management.

---

## Prerequisites

- Azure account with access to Microsoft Entra ID (formerly Azure AD)
- Domain name pointing to your Headscale server
- Headscale deployed and accessible (Caddy handles TLS automatically)

---

## Part 1: Azure AD App Registration

### Step 1: Create App Registration

1. Navigate to: **Azure Portal** → **Microsoft Entra ID** → **App registrations**
2. Click **New registration**
3. Configure:
   - **Name**: `Headscale VPN` (or your preferred name)
   - **Supported account types**: **Accounts in this organizational directory only (Single tenant)**
     - Recommended for security - only your organization's users can authenticate
   - **Redirect URIs**: Leave blank for now (we'll add them in Step 2)
4. Click **Register**

### Step 2: Configure Redirect URIs

After creating the app registration:

1. Go to **Authentication** in the left sidebar
2. Click **Add a platform** → **Web**
3. Add **both** redirect URIs (replace `YOUR_DOMAIN` with your actual domain):

   ```
   https://YOUR_DOMAIN/oidc/callback
   https://YOUR_DOMAIN/admin/oidc/callback
   ```

   **Purpose:**
   - `https://YOUR_DOMAIN/oidc/callback` - Headscale client authentication (Tailscale devices)
   - `https://YOUR_DOMAIN/admin/oidc/callback` - Headplane web UI authentication

4. **Important**: Ensure there are no trailing slashes
5. Click **Configure**

### Step 3: Create Client Secret

1. Go to **Certificates & secrets** in the left sidebar
2. Click **New client secret**
3. Configure:
   - **Description**: `Headscale OIDC` (or your preferred name)
   - **Expires**: **24 months** (recommended - set a calendar reminder to rotate before expiry)
4. Click **Add**
5. **⚠️ CRITICAL**: Copy the **Value** field immediately
   - This is your client secret - it's only shown once
   - DO NOT copy the "Secret ID" - that's not the secret value
   - Store it securely (you'll need it in Step 5)

### Step 4: Note Required Configuration Values

You'll need these three values for configuration. Find them in your app registration:

| Value | Where to Find It |
|-------|------------------|
| **Application (Client) ID** | Overview page (top section) |
| **Directory (Tenant) ID** | Overview page (top section) |
| **Client Secret Value** | From Step 3 (you copied it already) |

**Alternative for Tenant ID**: You can use your `*.onmicrosoft.com` domain instead of the GUID. For example:
- GUID format: `12345678-1234-1234-1234-123456789abc`
- Domain format: `contoso.onmicrosoft.com`

Both formats work - the deployment scripts accept either.

---

## Part 2: Headscale Server Configuration

### Step 5: Run Configuration Wizard

SSH into your Headscale server and run:

```bash
sudo headscale-config
```

The wizard will prompt for:

1. **Domain**: Your server's domain (e.g., `vpn.example.com`)
2. **Azure Tenant ID**: From Step 4 (GUID or *.onmicrosoft.com)
3. **Azure Client ID**: From Step 4
4. **Azure Client Secret**: From Step 3 (paste the secret value)
5. **Allowed Email**: Email address allowed to authenticate (your Azure AD email)

**Example:**
```
Domain (e.g., vpn.example.com): vpn.mycompany.com
Azure Tenant ID: contoso.onmicrosoft.com
Azure Application (Client) ID: 12345678-abcd-1234-abcd-123456789abc
Azure Client Secret Value: [paste your secret - hidden on screen]
Allowed Email Address (for login): admin@contoso.onmicrosoft.com
```

The wizard will:
- Validate all inputs
- Generate configuration files from templates
- Create a Headscale API key for Headplane
- Restart all services
- Display service status

### Step 6: Verify Deployment

After configuration completes, check service status:

```bash
sudo headscale-healthcheck
```

Expected output:
```
✓ headscale is running
✓ caddy is running
✓ fail2ban is running
✓ Port 8080 (Headscale API) is listening
✓ Port 443 (HTTPS) is listening
✓ Headscale API is reachable
```

---

## Part 3: Testing Authentication

### Test 1: Headplane Web UI

1. Open your browser to: `https://YOUR_DOMAIN/admin`
2. You should be redirected to Microsoft login
3. Sign in with your Azure AD account (the allowed email from Step 5)
4. You should be redirected back to the Headplane dashboard

### Test 2: Tailscale Client Connection

On any device with Tailscale installed:

```bash
tailscale up --login-server https://YOUR_DOMAIN
```

Expected behavior:
1. Command prints a URL
2. Open the URL in a browser
3. Microsoft login page appears
4. Sign in with your Azure AD account
5. Browser shows "Success" message
6. Tailscale client connects

---

## Security Best Practices

### Client Secret Rotation

**Azure AD client secrets expire.** When yours is close to expiration:

1. Create a new client secret in Azure AD (Step 3)
2. Run `sudo headscale-config` on your server
3. Enter the new secret value
4. The old secret remains valid until it expires (zero downtime)

**Set a calendar reminder** for 2-3 weeks before expiration.

### API Key Rotation

The Headscale API key (used by Headplane) auto-rotates:
- **Schedule**: Weekly cron job checks expiration
- **Threshold**: Auto-rotates if <14 days remain
- **Manual rotation**: `sudo headscale-rotate-apikey`

### User Access Control

**Method 1: Headscale Configuration (Initial Setup)**
Edit the allowed users list during initial configuration via `headscale-config`.

**Method 2: Headplane UI (After Deployment)**
1. Log into Headplane: `https://YOUR_DOMAIN/admin`
2. Navigate to **Settings** → **Users**
3. Add/remove allowed email addresses

**Method 3: Direct Configuration Edit**
```bash
sudo nano /etc/headscale/config.yaml
# Edit the oidc.allowed_users section
sudo systemctl restart headscale
```

---

## Troubleshooting

### Issue: "Invalid redirect URI" Error

**Symptoms:**
- Error message during Azure AD login
- "AADSTS50011: The redirect URI specified in the request does not match"

**Solutions:**
1. Verify both redirect URIs are added in Azure AD → Authentication
2. Ensure exact match (no trailing slashes):
   - ✅ `https://vpn.example.com/oidc/callback`
   - ❌ `https://vpn.example.com/oidc/callback/`
3. Check domain matches (case-insensitive but must be exact)
4. Wait 5 minutes after adding URIs (Azure AD cache propagation)

### Issue: "Consent Required" or Permissions Error

**Symptoms:**
- "AADSTS65001: The user or administrator has not consented to use the application"
- Permissions error during login

**Solutions:**
1. Go to Azure AD → App registrations → Your app → **API permissions**
2. Verify these permissions are present:
   - Microsoft Graph → User.Read (usually added automatically)
3. If missing, click **Add a permission** → Microsoft Graph → Delegated → User.Read
4. Click **Grant admin consent** (if you have admin rights)

### Issue: Login Works but User Can't Connect Devices

**Symptoms:**
- Web UI login successful
- Tailscale client connection fails or shows "not authorized"

**Solutions:**
1. Verify user email is in allowed list:
   ```bash
   sudo grep -A 5 "allowed_users" /etc/headscale/config.yaml
   ```
2. Check Headscale logs for authorization errors:
   ```bash
   sudo journalctl -u headscale -n 50 | grep -i oidc
   ```
3. Ensure email in Azure AD matches exactly (case-sensitive)

### Issue: "Token Validation Failed"

**Symptoms:**
- Error during OIDC callback
- "Failed to verify token" in Headscale logs

**Solutions:**
1. Verify Tenant ID is correct in configuration:
   ```bash
   sudo grep AZURE_TENANT_ID /etc/environment.d/headscale.conf
   ```
2. Check system time is synchronized:
   ```bash
   timedatectl status
   ```
3. If time is off, synchronize:
   ```bash
   sudo timedatectl set-ntp true
   ```

### Issue: Certificate Errors

**Symptoms:**
- "SSL certificate problem" errors
- Browser shows "Not Secure" warning

**Solutions:**
1. Verify domain DNS points to server:
   ```bash
   nslookup YOUR_DOMAIN
   ```
2. Check Caddy certificate status:
   ```bash
   sudo caddy validate --config /etc/caddy/Caddyfile
   ```
3. View certificate expiry:
   ```bash
   sudo headscale-healthcheck | grep -i cert
   ```
4. Force certificate renewal (if needed):
   ```bash
   sudo systemctl restart caddy
   ```

---

## Advanced Configuration

### Multi-Tenant Support

To allow users from multiple Azure AD tenants:

1. Change app registration to **multi-tenant**:
   - Azure AD → App registrations → Your app → **Authentication**
   - Supported account types → **Accounts in any organizational directory**
2. Update Headscale issuer URL:
   ```bash
   sudo nano /etc/headscale/templates/headscale.yaml.tpl
   # Change issuer to:
   # issuer: https://login.microsoftonline.com/common/v2.0
   ```
3. Regenerate configuration:
   ```bash
   sudo headscale-config
   ```

**Security Note**: Multi-tenant mode allows any Azure AD user to attempt login. Use `allowed_users` list strictly.

### Custom User Claims

To require specific group membership or attributes:

1. Add group claims to Azure AD token:
   - Azure AD → App registrations → Your app → **Token configuration**
   - Click **Add groups claim** → Select claim types
2. The deployment doesn't currently support group-based authorization
   - Feature request: https://github.com/juanfont/headscale/issues

### Testing Configuration

For testing without affecting production:

1. Use the Multipass testing workflow (see [TESTING.md](TESTING.md))
2. Create a separate Azure AD app registration for testing
3. Use ngrok for OAuth callbacks during testing

---

## Reference Links

- [Azure AD App Registration Docs](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [OIDC with Azure AD](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)
- [Headscale OIDC Documentation](https://headscale.net/ref/integration/oidc/)
- [Headplane Documentation](https://github.com/tale/headplane)

---

## Quick Reference Card

**Azure AD App Settings:**
```
Name: Headscale VPN
Type: Single tenant
Redirect URIs:
  - https://YOUR_DOMAIN/oidc/callback
  - https://YOUR_DOMAIN/admin/oidc/callback
Permissions: Microsoft Graph → User.Read
```

**Configuration Command:**
```bash
sudo headscale-config
```

**Health Check:**
```bash
sudo headscale-healthcheck
```

**API Key Rotation:**
```bash
sudo headscale-rotate-apikey
```

**View Configuration:**
```bash
cat /etc/environment.d/headscale.conf
cat /etc/headscale/config.yaml | grep -A 10 oidc
```

**Service Status:**
```bash
systemctl status headscale
systemctl status headplane
systemctl status caddy
```

---

**Last Updated:** 2025-12-25
**Repository:** https://github.com/anonhostpi/Headscale-VPS
