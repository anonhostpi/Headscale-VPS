# PLAN: Add Matrix Homeserver (Conduit) to Headscale VPS

## Overview

Add a Matrix homeserver (Continuwuity/Conduit-family) to the existing Headscale-VPS
deployment. Follows the existing `write_files/` + setup script pattern with minimal
`cloud-init.yml` changes.

## Commits

<!-- ANNOTATIONS:START -->
<!-- ANNOTATIONS:END -->

### Commit 1: `write_files/etc/headscale/versions.conf` - Add CONDUIT_VERSION and CONDUIT_SHA256 variables for Continuwuity binary pinning. Follows existing pattern for Headscale/Headplane version pinning.

### write_files.etc.headscale.versions.conduit-version-config

> **File**: `write_files/etc/headscale/versions.conf`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add CONDUIT_VERSION and CONDUIT_SHA256 variables for Continuwuity binary pinning. Follows existing pattern for Headscale/Headplane version pinning.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 2: `write_files/etc/headscale/constants.conf` - Add Matrix-related constants: CONDUIT_LISTEN_PORT, MATRIX_LOG_SIZE, MATRIX_LOG_KEEP. Follows existing constants pattern.

### write_files.etc.headscale.constants.matrix-constants

> **File**: `write_files/etc/headscale/constants.conf`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add Matrix-related constants: CONDUIT_LISTEN_PORT, MATRIX_LOG_SIZE, MATRIX_LOG_KEEP. Follows existing constants pattern.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 3: `write_files/etc/matrix-conduit/conduit.toml.tpl` - Conduit homeserver configuration template. Uses envsubst variables for MATRIX_SERVER_NAME and MATRIX_REGISTRATION_TOKEN. Binds to 127.0.0.1:6167 behind Caddy.

### write_files.etc.matrix-conduit.conduit.toml.conduit-config-template

> **File**: `write_files/etc/matrix-conduit/conduit.toml.tpl`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Conduit homeserver configuration template. Uses envsubst variables for MATRIX_SERVER_NAME and MATRIX_REGISTRATION_TOKEN. Binds to 127.0.0.1:6167 behind Caddy.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 4: `write_files/etc/systemd/system/conduit.service` - Systemd service unit for Conduit with full hardening (NoNewPrivileges, ProtectSystem=strict, SystemCallFilter, etc.). Matches existing headscale.service hardening pattern.

### write_files.etc.systemd.system.conduit.conduit-systemd-unit

> **File**: `write_files/etc/systemd/system/conduit.service`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Systemd service unit for Conduit with full hardening (NoNewPrivileges, ProtectSystem=strict, SystemCallFilter, etc.). Matches existing headscale.service hardening pattern.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 5: `write_files/etc/headscale/templates/Caddyfile-matrix.tpl` - Caddy reverse proxy template for Matrix. Handles client-server API (/_matrix/*), federation port 8448, and well-known delegation endpoints. Uses envsubst variables.

### write_files.etc.headscale.templates.Caddyfile-matrix.caddy-matrix-template

> **File**: `write_files/etc/headscale/templates/Caddyfile-matrix.tpl`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Caddy reverse proxy template for Matrix. Handles client-server API (/_matrix/*), federation port 8448, and well-known delegation endpoints. Uses envsubst variables.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 6: `write_files/opt/install-matrix.sh` - Install script for Conduit/Continuwuity. Creates conduit user, downloads binary with SHA256 verification, creates directories, opens UFW port 8448, enables systemd service. Follows setup-headscale.sh patterns.

### write_files.opt.install-matrix.matrix-install-script

> **File**: `write_files/opt/install-matrix.sh`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Install script for Conduit/Continuwuity. Creates conduit user, downloads binary with SHA256 verification, creates directories, opens UFW port 8448, enables systemd service. Follows setup-headscale.sh patterns.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 7: `write_files/usr/local/bin/matrix-config` - Post-deploy configuration wizard for Matrix. Prompts for Matrix domain, server_name, and registration token. Processes conduit.toml.tpl and Caddyfile-matrix.tpl via envsubst. Reloads Caddy and starts Conduit. Uses shared headscale-common.sh library.

### write_files.usr.local.bin.matrix-config-wizard

> **File**: `write_files/usr/local/bin/matrix-config`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Post-deploy configuration wizard for Matrix. Prompts for Matrix domain, server_name, and registration token. Processes conduit.toml.tpl and Caddyfile-matrix.tpl via envsubst. Reloads Caddy and starts Conduit. Uses shared headscale-common.sh library.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 8: `write_files/usr/local/bin/matrix-create-bot` - Helper script for creating Matrix bot accounts. Uses the standard Matrix client-server /register endpoint with a registration token. Outputs the access token for bot configuration.

### write_files.usr.local.bin.matrix-bot-creator

> **File**: `write_files/usr/local/bin/matrix-create-bot`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Helper script for creating Matrix bot accounts. Uses the standard Matrix client-server /register endpoint with a registration token. Outputs the access token for bot configuration.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 9: `write_files/etc/fail2ban/filter.d/matrix-auth.conf` - Fail2ban filter for Matrix authentication failures. Matches Conduit log patterns for failed login attempts.

### write_files.etc.fail2ban.filter.d.matrix-auth.matrix-fail2ban-filter

> **File**: `write_files/etc/fail2ban/filter.d/matrix-auth.conf`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Fail2ban filter for Matrix authentication failures. Matches Conduit log patterns for failed login attempts.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 10: `write_files/etc/fail2ban/jail.d/matrix.conf` - Fail2ban jail for Matrix authentication. 5 attempts, 12h ban (matches existing OIDC jail settings).

### write_files.etc.fail2ban.jail.d.matrix.matrix-fail2ban-jail

> **File**: `write_files/etc/fail2ban/jail.d/matrix.conf`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Fail2ban jail for Matrix authentication. 5 attempts, 12h ban (matches existing OIDC jail settings).

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 11: `write_files/etc/logrotate.d/matrix` - Log rotation config for /var/log/matrix-conduit/conduit.log. Daily rotation, 7 days retention, matches existing headscale logrotate pattern.

### write_files.etc.logrotate.d.matrix-logrotate

> **File**: `write_files/etc/logrotate.d/matrix`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Log rotation config for /var/log/matrix-conduit/conduit.log. Daily rotation, 7 days retention, matches existing headscale logrotate pattern.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 12: `write_files.yaml` - Add write_files.yaml entries for all new Matrix files: conduit.toml.tpl, conduit.service, Caddyfile-matrix.tpl, install-matrix.sh, matrix-config, matrix-create-bot, fail2ban filter/jail, logrotate.

### write_files.manifest-matrix-entries

> **File**: `write_files.yaml`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add write_files.yaml entries for all new Matrix files: conduit.toml.tpl, conduit.service, Caddyfile-matrix.tpl, install-matrix.sh, matrix-config, matrix-create-bot, fail2ban filter/jail, logrotate.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 13: `cloud-init.yml` - Add single line to runcmd: /opt/install-matrix.sh. This is the only change to cloud-init.yml.

### cloud-init.runcmd-matrix-install

> **File**: `cloud-init.yml`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add single line to runcmd: /opt/install-matrix.sh. This is the only change to cloud-init.yml.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 14: `write_files/usr/local/bin/headscale-healthcheck` - Add Conduit health check to existing healthcheck script. Checks systemd service status and Matrix client-server API responsiveness (GET /_matrix/client/versions).

### write_files.usr.local.bin.healthcheck-matrix

> **File**: `write_files/usr/local/bin/headscale-healthcheck`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add Conduit health check to existing healthcheck script. Checks systemd service status and Matrix client-server API responsiveness (GET /_matrix/client/versions).

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | N/A | N/A |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 15: `README.md` - Add Matrix server section to README: architecture diagram update, Matrix endpoints, post-deploy matrix-config instructions, bot account creation, troubleshooting.

### README.readme-matrix-docs

> **File**: `README.md`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add Matrix server section to README: architecture diagram update, Matrix endpoints, post-deploy matrix-config instructions, bot account creation, troubleshooting.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | markdown | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |
