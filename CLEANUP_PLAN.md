# Cleanup Implementation Plan

**Date:** 2025-12-25
**Status:** PENDING APPROVAL
**Based on:** CODE_REVIEW.md (2025-12-25)
**Repository:** https://github.com/anonhostpi/Headscale-VPS

---

## Executive Summary

This plan implements fixes for **10 code quality issues** identified in CODE_REVIEW.md, organized into **4 phases** based on priority and effort. The plan emphasizes **incremental improvements** with clear rollback procedures.

**Total Estimated Effort:** 15-26 hours
**Risk Level:** Low (mostly refactoring and configuration changes)
**Breaking Changes:** None (backward compatible)

---

## Phase 1: Critical Code Duplication (MUST DO)

**Priority:** CRITICAL
**Effort:** 3-5 hours
**Risk:** Low
**Breaking Changes:** None

### Task 1.1: Extract encrypt_secret_if_supported() to Shared Library

**Addresses:** CR-001 (Critical - Function Duplicated 4x)
**Addresses:** CR-002 (Critical - Systemd Version Check Duplicated)

#### Implementation Steps

**Step 1.1.1: Create headscale-secrets.sh Library**

Create new file in cloud-init.yml after headscale-validators.sh:

```yaml
# Insert after line 151 in cloud-init.yml
- path: /usr/local/lib/headscale-secrets.sh
  permissions: "0644"
  content: |
    #!/bin/bash
    # secrets.sh - Shared secret management functions for Headscale VPS
    # Provides systemd-creds encryption with graceful degradation

    # Constants
    readonly SYSTEMD_MIN_VERSION=250
    readonly CREDSTORE_DIR="/etc/credstore.encrypted"

    # Check if systemd supports credential encryption
    # Returns: 0 if supported, 1 if not
    check_systemd_creds_support() {
      # Check if systemd-creds command exists
      if ! command -v systemd-creds >/dev/null 2>&1; then
        return 1
      fi

      # Check systemd version (need 250+)
      local systemd_version
      systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')

      if [ -z "$systemd_version" ]; then
        return 1
      fi

      if [ "$systemd_version" -lt "$SYSTEMD_MIN_VERSION" ]; then
        return 1
      fi

      return 0
    }

    # Encrypt a secret file using systemd-creds (if supported)
    # Args:
    #   $1 - Path to plaintext secret file
    #   $2 - Credential name (used in systemd service files)
    # Returns: 0 on success or graceful fallback, 1 on error
    encrypt_secret_if_supported() {
      local plain_file="$1"
      local cred_name="$2"
      local encrypted_file="$CREDSTORE_DIR/${cred_name}.cred"

      # Validate inputs
      if [ -z "$plain_file" ] || [ -z "$cred_name" ]; then
        echo "Error: encrypt_secret_if_supported() requires 2 arguments" >&2
        return 1
      fi

      if [ ! -f "$plain_file" ]; then
        echo "Error: Secret file not found: $plain_file" >&2
        return 1
      fi

      # Check if systemd-creds is supported
      if ! check_systemd_creds_support; then
        # Graceful degradation - use plaintext with 600 permissions
        chmod 600 "$plain_file"
        return 0
      fi

      # Create credstore directory if it doesn't exist
      mkdir -p "$CREDSTORE_DIR"
      chmod 700 "$CREDSTORE_DIR"

      # Encrypt the secret
      local encrypt_output encrypt_error
      encrypt_output=$(systemd-creds encrypt --name="$cred_name" "$plain_file" "$encrypted_file" 2>&1)
      encrypt_error=$?

      if [ $encrypt_error -eq 0 ]; then
        chmod 600 "$encrypted_file"

        # Use print_success if available (from headscale-common.sh)
        if command -v print_success >/dev/null 2>&1; then
          print_success "Encrypted $cred_name using systemd-creds"
        else
          echo "[OK] Encrypted $cred_name using systemd-creds"
        fi

        return 0
      else
        # Encryption failed - fall back to plaintext
        if command -v print_warning >/dev/null 2>&1; then
          print_warning "Failed to encrypt $cred_name, using plaintext"
        else
          echo "[WARNING] Failed to encrypt $cred_name, using plaintext"
        fi

        if [ -n "$encrypt_output" ]; then
          echo "  Error details: $encrypt_output" >&2
        fi

        chmod 600 "$plain_file"
        return 0
      fi
    }

    # Get systemd version (for debugging/info purposes)
    get_systemd_version() {
      systemctl --version | head -n1 | awk '{print $2}'
    }
```

**Files Modified:**
- cloud-init.yml: Insert new section after line 151

---

**Step 1.1.2: Update headscale-config to Use Shared Library**

**File:** cloud-init.yml
**Lines to modify:** 193-537 (headscale-config)

**Changes:**

1. **Add library source (after line 201):**
```yaml
# Line 199-202 (current):
# Load shared libraries
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-validators.sh

# UPDATE TO:
# Load shared libraries
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-validators.sh
source /usr/local/lib/headscale-secrets.sh
```

2. **Remove local encrypt_secret_if_supported() function (lines 286-320):**
```yaml
# DELETE lines 285-320 entirely:
# Encrypt a secret file using systemd-creds (if supported)
encrypt_secret_if_supported() {
  [... entire function ...]
}
```

3. **Keep function calls unchanged (lines 331, 383):**
```yaml
# Line 331 (no change):
encrypt_secret_if_supported "$secret_file" "oidc_client_secret"

# Line 383 (no change):
encrypt_secret_if_supported "$api_key_file" "headscale_api_key"
```

**Files Modified:**
- cloud-init.yml lines 199-202: Add source statement
- cloud-init.yml lines 285-320: Remove duplicate function

**Line Count Change:** -35 lines (net reduction)

---

**Step 1.1.3: Update headscale-rotate-apikey to Use Shared Library**

**File:** cloud-init.yml
**Lines to modify:** 993-1126 (headscale-rotate-apikey)

**Changes:**

1. **Add library source (after line 1000):**
```yaml
# Line 999-1000 (current):
# Load shared libraries
source /usr/local/lib/headscale-common.sh

# UPDATE TO:
# Load shared libraries
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-secrets.sh
```

2. **Remove local encrypt_secret_if_supported() function (lines 1008-1041):**
```yaml
# DELETE lines 1007-1041 entirely
```

3. **Keep function call unchanged (line 1088):**
```yaml
# Line 1088 (no change):
encrypt_secret_if_supported "$API_KEY_FILE" "headscale_api_key"
```

**Files Modified:**
- cloud-init.yml line 1000: Add source statement
- cloud-init.yml lines 1007-1041: Remove duplicate function

**Line Count Change:** -34 lines (net reduction)

---

**Step 1.1.4: Update msmtp-config to Use Shared Library**

**File:** cloud-init.yml
**Lines to modify:** 1520-1643 (msmtp-config)

**Changes:**

1. **Add library source (after line 1528):**
```yaml
# Line 1526-1528 (current):
# Load shared libraries
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-validators.sh

# UPDATE TO:
# Load shared libraries
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-validators.sh
source /usr/local/lib/headscale-secrets.sh
```

2. **Remove local encrypt_secret_if_supported() function (lines 1536-1569):**
```yaml
# DELETE lines 1535-1569 entirely
```

3. **Keep function call unchanged (line 1611):**
```yaml
# Line 1611 (no change):
encrypt_secret_if_supported "$PASSWORD_FILE" "smtp_password"
```

**Files Modified:**
- cloud-init.yml line 1528: Add source statement
- cloud-init.yml lines 1535-1569: Remove duplicate function

**Line Count Change:** -34 lines (net reduction)

---

**Step 1.1.5: Update headscale-migrate-secrets to Use Shared Library**

**File:** cloud-init.yml
**Lines to modify:** 1158-1309 (headscale-migrate-secrets)

**Changes:**

1. **Add library source (after line 1165):**
```yaml
# Line 1164-1165 (current):
# Load shared libraries
source /usr/local/lib/headscale-common.sh

# UPDATE TO:
# Load shared libraries
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-secrets.sh
```

2. **Remove local systemd version check (lines 1174-1180):**
```yaml
# DELETE lines 1174-1180:
# Check systemd version (need 250+ for systemd-creds)
SYSTEMD_VERSION=$(systemctl --version | head -n1 | awk '{print $2}')
if [ "$SYSTEMD_VERSION" -lt 250 ]; then
  print_error "systemd version $SYSTEMD_VERSION is too old (need 250+)"
  print_info "Keeping plaintext secrets with 600 permissions"
  exit 1
fi

# REPLACE WITH:
# Check systemd-creds support
if ! check_systemd_creds_support; then
  SYSTEMD_VERSION=$(get_systemd_version)
  print_error "systemd-creds not supported (version $SYSTEMD_VERSION < 250)"
  print_info "Keeping plaintext secrets with 600 permissions"
  exit 1
fi
```

3. **Update encrypt_secret() function to use shared version (lines 1187-1218):**
```yaml
# CURRENT (lines 1187-1218):
encrypt_secret() {
  local plain_file="$1"
  local cred_name="$2"
  local encrypted_file="$CREDSTORE/${cred_name}.cred"
  [... implementation ...]
}

# UPDATE TO:
encrypt_secret() {
  # Wrapper around shared function for this script
  # Args: $1=plain_file, $2=cred_name
  encrypt_secret_if_supported "$1" "$2"
}
```

**Files Modified:**
- cloud-init.yml line 1165: Add source statement
- cloud-init.yml lines 1174-1180: Update version check to use shared function
- cloud-init.yml lines 1187-1218: Simplify to wrapper function

**Line Count Change:** -28 lines (net reduction)

---

#### Testing Steps

**Test 1.1.1: Verify Shared Library Loads Correctly**
```bash
# SSH into test VM
multipass shell headscale-test

# Test library loading
sudo bash -c '
  source /usr/local/lib/headscale-secrets.sh
  if [ $? -eq 0 ]; then
    echo "✓ Library loads successfully"
  else
    echo "✗ Library failed to load"
    exit 1
  fi
'

# Test function availability
sudo bash -c '
  source /usr/local/lib/headscale-secrets.sh
  if command -v encrypt_secret_if_supported >/dev/null; then
    echo "✓ encrypt_secret_if_supported() is available"
  else
    echo "✗ Function not found"
    exit 1
  fi
'
```

**Test 1.1.2: Test headscale-config with Shared Library**
```bash
# Run headscale-config (will source updated library)
sudo headscale-config

# Expected: Configuration wizard runs normally
# Expected: OIDC secret and API key are encrypted (if systemd 250+)
```

**Test 1.1.3: Test API Key Rotation with Shared Library**
```bash
# Rotate API key
sudo headscale-rotate-apikey

# Expected: New key created and encrypted
# Expected: No errors about missing functions
```

**Test 1.1.4: Test Secrets Migration with Shared Library**
```bash
# Check migration status
sudo headscale-migrate-secrets status

# Expected: Shows encryption status using shared functions
```

#### Rollback Procedure

If issues are found, revert changes:

```bash
# 1. SSH into VM
multipass shell headscale-test

# 2. Restore from git (if committed)
cd /path/to/repo
git revert <commit-hash>

# 3. Re-deploy cloud-init.yml
multipass delete headscale-test
multipass purge
./Deploy-Headscale.ps1

# 4. Or manually restore functions in each script
# (Keep backup of old cloud-init.yml)
```

#### Success Criteria

- ✅ All 4 scripts (headscale-config, headscale-rotate-apikey, msmtp-config, headscale-migrate-secrets) run without errors
- ✅ Secrets are encrypted when systemd 250+ is available
- ✅ Graceful degradation to plaintext on older systemd versions
- ✅ Net line count reduction of ~130 lines

---

## Phase 2: High Priority Improvements (SHOULD DO)

**Priority:** HIGH
**Effort:** 2.5-3.5 hours
**Risk:** Low
**Breaking Changes:** None

### Task 2.1: Create Centralized Constants Configuration

**Addresses:** CR-003 (High - Hardcoded Constants Scattered)

#### Implementation Steps

**Step 2.1.1: Create constants.conf**

Add new file in cloud-init.yml after versions.conf:

```yaml
# Insert after line 60 in cloud-init.yml (after versions.conf)
- path: /etc/headscale/constants.conf
  permissions: "0644"
  content: |
    # Headscale VPS Constants Configuration
    # Centralized timeouts, thresholds, and magic numbers
    # Update these values carefully and test before deploying to production

    # API Key Management
    readonly API_KEY_EXPIRATION_DAYS=90
    readonly API_KEY_WARNING_THRESHOLD_DAYS=14

    # Systemd
    readonly SYSTEMD_MIN_VERSION=250

    # Service Startup
    readonly SERVICE_START_RETRY_COUNT=30
    readonly SERVICE_START_RETRY_DELAY=1  # seconds

    # Health Check Thresholds
    readonly CERT_EXPIRY_WARNING_DAYS=14
    readonly DISK_WARNING_THRESHOLD_PCT=80

    # Fail2ban Configuration
    readonly FAIL2BAN_SSH_MAXRETRY=4
    readonly FAIL2BAN_SSH_FINDTIME="10m"
    readonly FAIL2BAN_SSH_BANTIME="24h"

    readonly FAIL2BAN_OIDC_MAXRETRY=5
    readonly FAIL2BAN_OIDC_FINDTIME="10m"
    readonly FAIL2BAN_OIDC_BANTIME="12h"

    readonly FAIL2BAN_AUTHKEY_MAXRETRY=5
    readonly FAIL2BAN_AUTHKEY_FINDTIME="10m"
    readonly FAIL2BAN_AUTHKEY_BANTIME="12h"

    readonly FAIL2BAN_RECIDIVE_MAXRETRY=3
    readonly FAIL2BAN_RECIDIVE_FINDTIME="1d"
    readonly FAIL2BAN_RECIDIVE_BANTIME="1w"

    # Logging
    readonly LOG_ROTATION_DAYS=7
    readonly CADDY_LOG_SIZE="10mb"
    readonly CADDY_LOG_KEEP=5
```

**Files Modified:**
- cloud-init.yml: Insert new section after line 60

---

**Step 2.1.2: Update headscale-config to Use Constants**

**File:** cloud-init.yml
**Lines to modify:** 193-537 (headscale-config)

**Changes:**

1. **Source constants.conf (after line 201):**
```yaml
# Load shared libraries and constants
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-validators.sh
source /usr/local/lib/headscale-secrets.sh
source /etc/headscale/constants.conf
```

2. **Replace hardcoded retry count (line 342):**
```yaml
# BEFORE (line 342):
local retries=30

# AFTER:
local retries=${SERVICE_START_RETRY_COUNT}
```

3. **Replace hardcoded sleep delay (line 347):**
```yaml
# BEFORE (line 347):
sleep 1

# AFTER:
sleep ${SERVICE_START_RETRY_DELAY}
```

4. **Replace hardcoded API key expiration (line 357):**
```yaml
# BEFORE (line 357):
api_create_output=$(headscale apikeys create --expiration 90d 2>&1)

# AFTER:
api_create_output=$(headscale apikeys create --expiration ${API_KEY_EXPIRATION_DAYS}d 2>&1)
```

5. **Replace hardcoded expiration date calculation (line 377):**
```yaml
# BEFORE (line 377):
date -d "+90 days" +%Y-%m-%d > /var/lib/headscale/api_key_expires

# AFTER:
date -d "+${API_KEY_EXPIRATION_DAYS} days" +%Y-%m-%d > /var/lib/headscale/api_key_expires
```

6. **Replace hardcoded warning threshold (line 391):**
```yaml
# BEFORE (line 391):
if [ $days_left -lt 14 ]; then

# AFTER:
if [ $days_left -lt ${API_KEY_WARNING_THRESHOLD_DAYS} ]; then
```

**Files Modified:**
- cloud-init.yml lines 342, 347, 357, 377, 391: Replace hardcoded values

---

**Step 2.1.3: Update headscale-rotate-apikey to Use Constants**

**File:** cloud-init.yml
**Lines to modify:** 993-1126 (headscale-rotate-apikey)

**Changes:**

1. **Source constants.conf (after line 1000):**
```yaml
source /usr/local/lib/headscale-common.sh
source /usr/local/lib/headscale-secrets.sh
source /etc/headscale/constants.conf
```

2. **Replace hardcoded API key expiration (line 1053):**
```yaml
# BEFORE (line 1053):
api_create_output=$(headscale apikeys create --expiration 90d 2>&1)

# AFTER:
api_create_output=$(headscale apikeys create --expiration ${API_KEY_EXPIRATION_DAYS}d 2>&1)
```

3. **Replace hardcoded expiration calculation (line 1081):**
```yaml
# BEFORE (line 1081):
date -d "+90 days" +%Y-%m-%d > "$API_KEY_EXPIRES"

# AFTER:
date -d "+${API_KEY_EXPIRATION_DAYS} days" +%Y-%m-%d > "$API_KEY_EXPIRES"
```

4. **Replace hardcoded success message (line 1085):**
```yaml
# BEFORE (line 1085):
echo -e "${GREEN}[OK]${NC} New API key generated (expires in 90 days)"

# AFTER:
echo -e "${GREEN}[OK]${NC} New API key generated (expires in ${API_KEY_EXPIRATION_DAYS} days)"
```

**Files Modified:**
- cloud-init.yml lines 1053, 1081, 1085: Replace hardcoded values

---

**Step 2.1.4: Update headscale-healthcheck to Use Constants**

**File:** cloud-init.yml
**Lines to modify:** 1314-1436 (headscale-healthcheck)

**Changes:**

1. **Source constants.conf (at beginning):**
```yaml
# Line 1316 (after shebang):
#!/bin/bash
# Comprehensive health check for Headscale deployment

# Load constants
source /etc/headscale/constants.conf

HEALTH_STATUS=0
REPORT=""
```

2. **Replace cert expiry threshold (line 1371):**
```yaml
# BEFORE (line 1371):
if [ $DAYS_LEFT -gt 14 ]; then

# AFTER:
if [ $DAYS_LEFT -gt ${CERT_EXPIRY_WARNING_DAYS} ]; then
```

3. **Replace API key expiry threshold (line 1392):**
```yaml
# BEFORE (line 1392):
if [ $DAYS_LEFT -gt 14 ]; then

# AFTER:
if [ $DAYS_LEFT -gt ${API_KEY_WARNING_THRESHOLD_DAYS} ]; then
```

4. **Replace disk usage threshold (line 1405):**
```yaml
# BEFORE (line 1405):
if [ -n "$USAGE" ] && [ "$USAGE" -lt 80 ]; then

# AFTER:
if [ -n "$USAGE" ] && [ "$USAGE" -lt ${DISK_WARNING_THRESHOLD_PCT} ]; then
```

**Files Modified:**
- cloud-init.yml lines 1371, 1392, 1405: Replace hardcoded thresholds

---

**Step 2.1.5: Update Fail2ban Configurations to Use Constants**

**File:** cloud-init.yml
**Lines to modify:** Fail2ban jail files (1944-2022)

**Note:** Fail2ban configurations are static files, not bash scripts. We'll use envsubst to process them.

**Changes:**

1. **Create fail2ban config template processor:**

Add new file before fail2ban configs:

```yaml
# Insert before line 1939 (before fail2ban configs)
- path: /usr/local/bin/update-fail2ban-config
  permissions: "0755"
  content: |
    #!/bin/bash
    # Update fail2ban configurations from constants.conf
    set -e

    source /etc/headscale/constants.conf

    # Export for envsubst
    export FAIL2BAN_SSH_MAXRETRY
    export FAIL2BAN_SSH_FINDTIME
    export FAIL2BAN_SSH_BANTIME
    export FAIL2BAN_OIDC_MAXRETRY
    export FAIL2BAN_OIDC_FINDTIME
    export FAIL2BAN_OIDC_BANTIME
    export FAIL2BAN_AUTHKEY_MAXRETRY
    export FAIL2BAN_AUTHKEY_FINDTIME
    export FAIL2BAN_AUTHKEY_BANTIME
    export FAIL2BAN_RECIDIVE_MAXRETRY
    export FAIL2BAN_RECIDIVE_FINDTIME
    export FAIL2BAN_RECIDIVE_BANTIME

    # Process templates (if they exist)
    if [ -f /etc/fail2ban/jail.d/sshd.conf.tpl ]; then
      envsubst < /etc/fail2ban/jail.d/sshd.conf.tpl > /etc/fail2ban/jail.d/sshd.conf
    fi

    # Restart fail2ban to apply changes
    systemctl restart fail2ban

    echo "Fail2ban configuration updated from constants.conf"
```

2. **Convert sshd.conf to template (lines 1944-1957):**
```yaml
# BEFORE (static file):
- path: /etc/fail2ban/jail.d/sshd.conf
  permissions: "0644"
  content: |
    [sshd]
    enabled = true
    port = ssh
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = 4
    findtime = 10m
    bantime = 24h
    action = %(action_)s
             msmtp-mail[name=SSH]

# AFTER (template):
- path: /etc/fail2ban/jail.d/sshd.conf.tpl
  permissions: "0644"
  content: |
    [sshd]
    enabled = true
    port = ssh
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = ${FAIL2BAN_SSH_MAXRETRY}
    findtime = ${FAIL2BAN_SSH_FINDTIME}
    bantime = ${FAIL2BAN_SSH_BANTIME}
    action = %(action_)s
             msmtp-mail[name=SSH]

# Also create processed version on first boot
- path: /etc/fail2ban/jail.d/sshd.conf
  permissions: "0644"
  content: |
    [sshd]
    enabled = true
    port = ssh
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = 4
    findtime = 10m
    bantime = 24h
    action = %(action_)s
             msmtp-mail[name=SSH]
```

**Repeat for other fail2ban jails (caddy-oidc, headscale-authkey, recidive)**

**Files Modified:**
- cloud-init.yml: Add update-fail2ban-config script before line 1939
- cloud-init.yml lines 1944-2022: Convert to templates + static files

---

#### Testing Steps

**Test 2.1.1: Verify Constants File Created**
```bash
# Check constants.conf exists
multipass exec headscale-test -- cat /etc/headscale/constants.conf

# Expected: File contents show all constants
```

**Test 2.1.2: Test Scripts Use Constants**
```bash
# Modify a constant
multipass exec headscale-test -- sudo bash -c '
  sed -i "s/API_KEY_EXPIRATION_DAYS=90/API_KEY_EXPIRATION_DAYS=120/" /etc/headscale/constants.conf
'

# Rotate API key
multipass exec headscale-test -- sudo headscale-rotate-apikey

# Check expiration
multipass exec headscale-test -- cat /var/lib/headscale/api_key_expires

# Expected: Expires in 120 days (not 90)
```

**Test 2.1.3: Test Fail2ban Uses Constants**
```bash
# Update fail2ban config from constants
multipass exec headscale-test -- sudo update-fail2ban-config

# Check resulting config
multipass exec headscale-test -- cat /etc/fail2ban/jail.d/sshd.conf

# Expected: Values match constants.conf
```

#### Rollback Procedure

Revert constants.conf changes:
```bash
# Remove constants.conf
sudo rm /etc/headscale/constants.conf

# Restore hardcoded values in scripts
# (Restore from backup or previous commit)
```

#### Success Criteria

- ✅ Constants.conf file created and loaded by all scripts
- ✅ API key expiration uses constant (verified by test)
- ✅ Health check thresholds use constants
- ✅ Fail2ban configs can be updated from constants
- ✅ Documentation updated to reference constants.conf

---

### Task 2.2: Fix PowerShell Email Validation Regex

**Addresses:** CR-005 (High - Validation Inconsistency)

#### Implementation Steps

**Step 2.2.1: Update Deploy-Headscale.ps1 Email Validation**

**File:** Deploy-Headscale.ps1
**Line to modify:** 188

**Change:**

```powershell
# BEFORE (line 188):
"Email" {
    if ($value -notmatch '^[^@]+@[^@]+\.[^@]+$') {
        Write-Host "  Invalid email format. Please try again." -ForegroundColor Red
        $valid = $false
    }
}

# AFTER (RFC 5322 compliant - matches Bash validators.sh):
"Email" {
    # RFC 5322 compliant (simplified) - must match Bash validation
    if ($value -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
        Write-Host "  Invalid email format. Please try again." -ForegroundColor Red
        $valid = $false
    }
}
```

**Files Modified:**
- Deploy-Headscale.ps1 line 188: Update regex pattern

---

#### Testing Steps

**Test 2.2.1: Test Invalid Email Rejection**
```powershell
# Test with invalid emails
$testCases = @(
    "user@@example.com",  # Double @
    "@example.com",       # Missing local part
    "user@",              # Missing domain
    "user@.com",          # Missing domain name
    "user"                # No @ at all
)

foreach ($email in $testCases) {
    # Should all be rejected by new regex
    if ($email -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
        Write-Host "✗ FAIL: $email should be rejected" -ForegroundColor Red
    } else {
        Write-Host "✓ PASS: $email correctly rejected" -ForegroundColor Green
    }
}
```

**Test 2.2.2: Test Valid Email Acceptance**
```powershell
# Test with valid emails
$testCases = @(
    "user@example.com",
    "user.name@example.com",
    "user+tag@example.co.uk",
    "user123@test-domain.org"
)

foreach ($email in $testCases) {
    # Should all be accepted
    if ($email -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
        Write-Host "✓ PASS: $email correctly accepted" -ForegroundColor Green
    } else {
        Write-Host "✗ FAIL: $email should be accepted" -ForegroundColor Red
    }
}
```

**Test 2.2.3: Test End-to-End with Deployment Script**
```powershell
# Run deployment with test email
.\Deploy-Headscale.ps1

# When prompted for email, try:
# 1. Invalid: user@@example.com (should be rejected)
# 2. Valid: user@example.com (should be accepted)
```

#### Rollback Procedure

```powershell
# Revert to old regex if issues found
# Edit Deploy-Headscale.ps1 line 188:
if ($value -notmatch '^[^@]+@[^@]+\.[^@]+$') {
```

#### Success Criteria

- ✅ Invalid emails (double @, missing parts) are rejected in PowerShell
- ✅ Valid emails are accepted in PowerShell
- ✅ PowerShell validation matches Bash validation exactly
- ✅ End-to-end deployment test passes with valid email

---

## Phase 3: Medium Priority Improvements (NICE TO HAVE)

**Priority:** MEDIUM
**Effort:** 4-6 hours
**Risk:** Low
**Breaking Changes:** None

### Task 3.1: Fix Remaining Error Handling Gaps

**Addresses:** CR-006 (Medium - Error Handling Inconsistencies)

#### Implementation Steps

**Step 3.1.1: Update headscale-healthcheck Error Handling**

**File:** cloud-init.yml
**Lines to modify:** 1314-1436 (headscale-healthcheck)

**Changes:**

Apply Phase 6 error handling pattern to all `2>/dev/null` usages.

**Example for check_port() (lines 1336-1345):**

```bash
# BEFORE:
check_port() {
  local port=$1
  local description=$2
  if ss -tuln 2>/dev/null | grep -q ":$port "; then
    REPORT="${REPORT}✓ Port $port ($description) is listening\n"
  else
    REPORT="${REPORT}✗ Port $port ($description) is NOT listening\n"
    HEALTH_STATUS=1
  fi
}

# AFTER:
check_port() {
  local port=$1
  local description=$2
  local ss_output ss_error

  ss_output=$(ss -tuln 2>&1)
  ss_error=$?

  if [ $ss_error -ne 0 ]; then
    REPORT="${REPORT}⚠ Could not check port $port (ss command failed)\n"
    echo "  Error details: $ss_output" >&2
    return 1
  fi

  if echo "$ss_output" | grep -q ":$port "; then
    REPORT="${REPORT}✓ Port $port ($description) is listening\n"
  else
    REPORT="${REPORT}✗ Port $port ($description) is NOT listening\n"
    HEALTH_STATUS=1
  fi
}
```

**Repeat for:**
- check_cert_expiry() - Lines 1358-1381 (openssl, grep, date commands)
- check_api_key_expiry() - Lines 1384-1399 (cat, date commands)
- check_disk_space() - Lines 1402-1411 (df command)

**Files Modified:**
- cloud-init.yml lines 1336-1411: Update all check functions

---

**Step 3.1.2: Update headscale-update Error Handling**

**File:** cloud-init.yml
**Lines to modify:** 1693-1917 (headscale-update)

**Changes:**

1. **Fix version check (line 1723):**
```bash
# BEFORE:
get_installed_headscale_version() {
  headscale version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1 || echo "unknown"
}

# AFTER:
get_installed_headscale_version() {
  local version_output version_error
  version_output=$(headscale version 2>&1)
  version_error=$?

  if [ $version_error -ne 0 ]; then
    echo "unknown"
    return 0
  fi

  echo "$version_output" | grep -oP 'v\d+\.\d+\.\d+' | head -1 || echo "unknown"
}
```

2. **Fix Headplane version check (line 1729):**
```bash
# BEFORE:
get_installed_headplane_version() {
  if [ -f /opt/headplane/package.json ]; then
    grep -oP '"version":\s*"\K[^"]+' /opt/headplane/package.json || echo "unknown"
  else
    echo "not-installed"
  fi
}

# AFTER:
get_installed_headplane_version() {
  if [ ! -f /opt/headplane/package.json ]; then
    echo "not-installed"
    return 0
  fi

  local version_output
  version_output=$(grep -oP '"version":\s*"\K[^"]+' /opt/headplane/package.json 2>&1)

  if [ -z "$version_output" ]; then
    echo "unknown"
  else
    echo "$version_output"
  fi
}
```

**Files Modified:**
- cloud-init.yml lines 1722-1732: Update version check functions

---

**Step 3.1.3: Update setup-headscale.sh Error Handling**

**File:** cloud-init.yml
**Lines to modify:** 2041-2264 (setup-headscale.sh)

**Changes:**

1. **Fix user check (line 2094):**
```bash
# BEFORE:
if ! id -u headscale > /dev/null 2>&1; then
  useradd --system --home /var/lib/headscale --shell /usr/sbin/nologin headscale
fi

# AFTER:
if ! id -u headscale >/dev/null 2>&1; then
  useradd --system --home /var/lib/headscale --shell /usr/sbin/nologin headscale
else
  echo "  User 'headscale' already exists, skipping creation"
fi
```

2. **Fix GPG fingerprint check (line 2126):**
```bash
# BEFORE:
ACTUAL_FINGERPRINT=$(gpg --no-default-keyring --keyring "$TEMP_KEYRING" --list-keys --with-colons 2>/dev/null | \
  grep '^fpr' | head -1 | cut -d':' -f10)

# AFTER:
local gpg_output gpg_error
gpg_output=$(gpg --no-default-keyring --keyring "$TEMP_KEYRING" --list-keys --with-colons 2>&1)
gpg_error=$?

if [ $gpg_error -ne 0 ]; then
  echo "ERROR: Failed to read GPG keyring"
  echo "  Error details: $gpg_output" >&2
  rm -f "$TEMP_KEYRING"
  exit 1
fi

ACTUAL_FINGERPRINT=$(echo "$gpg_output" | grep '^fpr' | head -1 | cut -d':' -f10)
```

**Files Modified:**
- cloud-init.yml lines 2094, 2126: Update error handling

---

#### Testing Steps

**Test 3.1.1: Test Health Check Error Handling**
```bash
# Simulate ss command failure
multipass exec headscale-test -- sudo bash -c '
  # Make ss fail by restricting permissions temporarily
  chmod 000 /bin/ss
  /usr/local/bin/headscale-healthcheck
  chmod 755 /bin/ss
'

# Expected: Warning message with error details (not silent failure)
```

**Test 3.1.2: Test Update Script Error Handling**
```bash
# Simulate headscale binary missing
multipass exec headscale-test -- sudo bash -c '
  mv /usr/local/bin/headscale /usr/local/bin/headscale.bak
  /usr/local/bin/headscale-update
  mv /usr/local/bin/headscale.bak /usr/local/bin/headscale
'

# Expected: "unknown" version, not crash or silent error
```

#### Rollback Procedure

Revert to `2>/dev/null` pattern if error handling causes issues.

#### Success Criteria

- ✅ All commands log errors with context (no `2>/dev/null`)
- ✅ Error messages help with debugging
- ✅ Scripts don't crash on command failures

---

### Task 3.2: Centralize Path Definitions

**Addresses:** CR-008 (Medium - No Centralized Configuration Constants)

#### Implementation Steps

**Step 3.2.1: Create headscale-paths.sh Library**

Add after headscale-secrets.sh:

```yaml
# Insert after headscale-secrets.sh (after line ~230)
- path: /usr/local/lib/headscale-paths.sh
  permissions: "0644"
  content: |
    #!/bin/bash
    # paths.sh - Centralized path definitions for Headscale VPS

    # Configuration directories
    readonly HEADSCALE_CONFIG_DIR="/etc/headscale"
    readonly HEADSCALE_TEMPLATES_DIR="${HEADSCALE_CONFIG_DIR}/templates"
    readonly HEADPLANE_CONFIG_DIR="/etc/headplane"
    readonly ENV_CONFIG_DIR="/etc/environment.d"
    readonly CREDSTORE_DIR="/etc/credstore.encrypted"

    # Data directories
    readonly HEADSCALE_DATA_DIR="/var/lib/headscale"
    readonly HEADPLANE_DATA_DIR="/var/lib/headplane"

    # Application directories
    readonly HEADPLANE_APP_DIR="/opt/headplane"
    readonly NVM_DIR="/opt/nvm"

    # Log directories
    readonly HEADSCALE_LOG_DIR="/var/log/headscale"
    readonly CADDY_LOG_DIR="/var/log/caddy"

    # Configuration files
    readonly ENV_FILE="${ENV_CONFIG_DIR}/headscale.conf"
    readonly VERSIONS_FILE="${HEADSCALE_CONFIG_DIR}/versions.conf"
    readonly CONSTANTS_FILE="${HEADSCALE_CONFIG_DIR}/constants.conf"
    readonly API_KEY_FILE="${HEADSCALE_DATA_DIR}/api_key"
    readonly API_KEY_EXPIRES="${HEADSCALE_DATA_DIR}/api_key_expires"
    readonly OIDC_SECRET_FILE="${HEADSCALE_DATA_DIR}/oidc_client_secret"
    readonly SMTP_PASSWORD_FILE="/etc/msmtp-password"

    # Shared library directory
    readonly HEADSCALE_LIB_DIR="/usr/local/lib"
```

**Files Modified:**
- cloud-init.yml: Insert new library after headscale-secrets.sh

---

**Step 3.2.2: Update Scripts to Use Path Constants**

**Priority scripts to update:**
1. headscale-config (uses 8+ paths)
2. headscale-rotate-apikey (uses 5+ paths)
3. msmtp-config (uses 3+ paths)
4. headscale-healthcheck (uses 6+ paths)

**Example for headscale-config (lines 203-204):**

```bash
# BEFORE:
ENV_FILE="/etc/environment.d/headscale.conf"
TEMPLATES_DIR="/etc/headscale/templates"

# AFTER:
source /usr/local/lib/headscale-paths.sh
# Use: $ENV_FILE and $HEADSCALE_TEMPLATES_DIR (already defined)
```

**Note:** This is a large refactoring affecting many files. Recommend doing incrementally and testing each script.

**Files Modified:**
- All major scripts: headscale-config, headscale-rotate-apikey, msmtp-config, headscale-healthcheck, install-headplane.sh

---

#### Testing Steps

Test each updated script individually to ensure paths resolve correctly.

#### Success Criteria

- ✅ All scripts load headscale-paths.sh successfully
- ✅ All scripts use path constants instead of hardcoded paths
- ✅ No path-related errors in any script

---

### Task 3.3: Add Encryption to Auto-Config

**Addresses:** CR-009 (Medium - Auto-Config Doesn't Use Encryption)

#### Implementation Steps

**Step 3.3.1: Update Deploy-Headscale.ps1 Auto-Config**

**File:** Deploy-Headscale.ps1
**Lines to modify:** 340-368 (auto-configure.sh)

**Changes:**

```powershell
# BEFORE (line 340-343):
# Write OIDC secret
echo -n "\$AZURE_CLIENT_SECRET" > /var/lib/headscale/oidc_client_secret
chown headscale:headscale /var/lib/headscale/oidc_client_secret
chmod 600 /var/lib/headscale/oidc_client_secret

# AFTER (add encryption):
# Write OIDC secret
echo -n "\$AZURE_CLIENT_SECRET" > /var/lib/headscale/oidc_client_secret
chown headscale:headscale /var/lib/headscale/oidc_client_secret
chmod 600 /var/lib/headscale/oidc_client_secret

# Encrypt secret using shared function
source /usr/local/lib/headscale-secrets.sh
encrypt_secret_if_supported /var/lib/headscale/oidc_client_secret "oidc_client_secret"

# BEFORE (line 353-357):
API_KEY=\$(headscale apikeys create --expiration 90d 2>/dev/null | tail -1)
echo -n "\$API_KEY" > /var/lib/headscale/api_key
chown headscale:headscale /var/lib/headscale/api_key
chmod 600 /var/lib/headscale/api_key
date -d "+90 days" +%Y-%m-%d > /var/lib/headscale/api_key_expires

# AFTER (add encryption):
API_KEY=\$(headscale apikeys create --expiration 90d 2>/dev/null | tail -1)
echo -n "\$API_KEY" > /var/lib/headscale/api_key
chown headscale:headscale /var/lib/headscale/api_key
chmod 600 /var/lib/headscale/api_key
date -d "+90 days" +%Y-%m-%d > /var/lib/headscale/api_key_expires

# Encrypt API key using shared function
encrypt_secret_if_supported /var/lib/headscale/api_key "headscale_api_key"
```

**Files Modified:**
- Deploy-Headscale.ps1 lines 343, 357: Add encryption calls

---

#### Testing Steps

**Test 3.3.1: Deploy with Auto-Config**
```powershell
# Run full deployment
.\Deploy-Headscale.ps1

# After deployment, check encryption status
multipass exec headscale-test -- sudo headscale-migrate-secrets status

# Expected: All secrets show as "encrypted" (if systemd 250+)
```

#### Success Criteria

- ✅ Auto-config encrypts OIDC secret and API key
- ✅ Encrypted credentials work with Headscale/Headplane services
- ✅ Testing workflow matches production security posture

---

## Phase 4: Low Priority (OPTIONAL)

**Priority:** LOW
**Effort:** 0.25 hours
**Risk:** Negligible
**Breaking Changes:** None

### Task 4.1: Move NVM Version to versions.conf

**Addresses:** CR-010 (Low - NVM Version Not in versions.conf)

#### Implementation Steps

**Step 4.1.1: Add NVM to versions.conf**

**File:** cloud-init.yml
**Lines to modify:** 38-60 (versions.conf)

**Changes:**

```yaml
# Add after line 43 (before NODE_VERSION):
# NVM (Node Version Manager)
NVM_VERSION="v0.40.1"
NVM_SHA256="d9835a30ce722c9dc8590e47e5ff8dcb89dd3f977c0c176f719745e84757381a"

# Node.js LTS version for Headplane (via nvm)
NODE_VERSION="22.11.0"
```

**Files Modified:**
- cloud-init.yml lines 43-46: Add NVM constants

---

**Step 4.1.2: Update install-headplane.sh to Use versions.conf**

**File:** cloud-init.yml
**Lines to modify:** 857-989 (install-headplane.sh)

**Changes:**

```bash
# BEFORE (lines 878-879):
NVM_VERSION="v0.40.1"
NVM_SHA256="d9835a30ce722c9dc8590e47e5ff8dcb89dd3f977c0c176f719745e84757381a"

# AFTER (load from versions.conf):
# Loaded from versions.conf at line 868:
# source /etc/headscale/versions.conf
NVM_VERSION="${NVM_VERSION:-v0.40.1}"  # Fallback if not in config
NVM_SHA256="${NVM_SHA256:-}"
```

**Files Modified:**
- cloud-init.yml lines 878-879: Remove hardcoded values (already loaded from versions.conf at line 868)

---

#### Testing Steps

**Test 4.1.1: Verify NVM Version from Config**
```bash
# Check versions.conf
multipass exec headscale-test -- cat /etc/headscale/versions.conf

# Should show NVM_VERSION and NVM_SHA256

# Reinstall Headplane
multipass exec headscale-test -- sudo /opt/install-headplane.sh

# Verify NVM version
multipass exec headscale-test -- /opt/nvm/nvm.sh --version
```

#### Success Criteria

- ✅ NVM version in versions.conf
- ✅ install-headplane.sh loads NVM version from config
- ✅ Headplane installation uses correct NVM version

---

## Deferred Tasks (Future Consideration)

### CR-004: Refactor Long Scripts (HIGH Effort)

**Recommendation:** DEFER

**Rationale:**
- Large architectural changes (4-8 hours per script × 5 scripts = 20-40 hours)
- High risk of introducing bugs
- Current scripts are functional and well-tested
- No specific pain points reported from usage

**Future Triggers for Reconsidering:**
- User reports difficulty understanding or modifying scripts
- Need to add significant new functionality
- Testing becomes painful due to coupling
- Performance issues identified

---

### CR-007: Template Management Improvements (MEDIUM Effort)

**Recommendation:** DEFER

**Rationale:**
- Current embedded approach works for single-file deployment
- External templates would complicate deployment
- No reported issues with template updates
- Validation script (Option 2) could be added if needed

**Future Triggers for Reconsidering:**
- Frequent template syntax errors discovered at runtime
- Need for environment-specific template variations
- Community requests for customizable templates

---

## Implementation Timeline

### Recommended Sequence

**Week 1:**
- Phase 1 (Critical): Extract encrypt_secret_if_supported() - **3-5 hours**
- Test thoroughly before proceeding

**Week 2:**
- Phase 2 Task 2.1 (High): Create constants.conf - **2-3 hours**
- Phase 2 Task 2.2 (High): Fix PowerShell email validation - **0.5 hours**

**Week 3:**
- Phase 3 Task 3.1 (Medium): Fix error handling - **1-2 hours**
- Phase 3 Task 3.2 (Medium): Centralize paths (partial - high-priority scripts only) - **2-3 hours**

**Week 4:**
- Phase 3 Task 3.3 (Medium): Auto-config encryption - **1 hour**
- Phase 4 Task 4.1 (Low): NVM to versions.conf - **0.25 hours**
- Final testing and documentation updates

**Total:** 10-16.75 hours over 4 weeks

---

## Risk Management

### Mitigation Strategies

1. **Version Control:**
   - Commit after each phase
   - Tag working versions
   - Enable easy rollback

2. **Testing:**
   - Test each change in isolation
   - Use Multipass VMs for throwaway testing
   - Verify both encrypted and plaintext paths

3. **Backup:**
   - Keep backup of working cloud-init.yml
   - Document rollback procedures for each task
   - Save VM snapshots before major changes

4. **Incremental Deployment:**
   - Don't attempt all phases at once
   - Complete Phase 1 and test thoroughly before Phase 2
   - Allow time between phases for real-world validation

---

## Success Metrics

| Metric | Baseline | Target | How to Measure |
|--------|----------|--------|----------------|
| Code Duplication | 4 instances | 0 instances | `grep -r "encrypt_secret_if_supported()" cloud-init.yml | wc -l` |
| Hardcoded Constants | 8 categories | 0 categories | Manual review of constants.conf usage |
| Error Suppressions | 11 locations | 0 locations | `grep -c "2>/dev/null" cloud-init.yml` |
| Validation Consistency | 2 different regexes | 1 regex | Compare Bash vs PowerShell patterns |
| Lines of Code | 2,268 | ~2,100 | `wc -l cloud-init.yml` |

---

## Documentation Updates Required

After completing cleanup:

1. **Update README.md:**
   - Document constants.conf and how to customize
   - Update version pinning section to include NVM
   - Add section on centralized path definitions

2. **Update TESTING.md:**
   - Note that auto-config now encrypts secrets
   - Update email validation examples

3. **Update AZURE_AD_SETUP.md:**
   - Reference email validation requirements (RFC 5322)

4. **Create CONFIGURATION.md (new file):**
   - Document all constants in constants.conf
   - Document all paths in headscale-paths.sh
   - Provide tuning guidance

5. **Update Technical Debt Plan:**
   - Mark CR-001 through CR-010 as resolved
   - Document deferred tasks (CR-004, CR-007)

---

## Appendix: File Change Summary

### Files Modified (Summary)

| File | Sections Modified | Lines Changed | Net Change |
|------|-------------------|---------------|------------|
| cloud-init.yml | Multiple | ~200 | -100 (reduction) |
| Deploy-Headscale.ps1 | 2 | ~10 | 0 |

### New Files Created

| File | Purpose | Lines |
|------|---------|-------|
| /usr/local/lib/headscale-secrets.sh | Shared encryption functions | ~80 |
| /usr/local/lib/headscale-paths.sh | Centralized path definitions | ~30 |
| /etc/headscale/constants.conf | Centralized constants | ~35 |
| /usr/local/bin/update-fail2ban-config | Fail2ban config updater | ~30 |

### Scripts Significantly Updated

| Script | Current Lines | Refactored Lines | Change |
|--------|---------------|------------------|--------|
| headscale-config | 345 | 310 | -35 (removed duplicate function) |
| headscale-rotate-apikey | 134 | 100 | -34 (removed duplicate function) |
| msmtp-config | 124 | 90 | -34 (removed duplicate function) |
| headscale-migrate-secrets | 152 | 124 | -28 (simplified with shared functions) |
| headscale-healthcheck | 123 | 135 | +12 (improved error handling) |
| install-headplane.sh | 133 | 131 | -2 (use versions.conf) |

---

**Plan Status:** ✅ READY FOR IMPLEMENTATION
**Next Step:** Begin Phase 1 Task 1.1 (Extract encrypt_secret_if_supported)
**Estimated Completion:** 4 weeks (assuming 4 hours/week effort)
