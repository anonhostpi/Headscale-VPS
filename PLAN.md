# PLAN: Coordination & Relay Server — Matrix + Unified Config

## Overview

Expand Headscale-VPS into a multi-service Coordination & Relay Server:
1. Add Matrix homeserver (Conduit/Continuwuity)
2. Add unified YAML-driven `server-config` wizard (replaces per-service wizards)
3. Add `yq` for YAML parsing
4. Update documentation and identity

## Commits

<!-- ANNOTATIONS:START -->
<!-- ANNOTATIONS:END -->

### Commit 1: `write_files/etc/headscale/versions.conf` - Add CONDUIT_VERSION, CONDUIT_SHA256, YQ_VERSION, and YQ_SHA256 for Continuwuity binary and yq YAML parser pinning.

### write_files.etc.headscale.versions.conduit-yq-versions

> **File**: `write_files/etc/headscale/versions.conf`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add CONDUIT_VERSION, CONDUIT_SHA256, YQ_VERSION, and YQ_SHA256 for Continuwuity binary and yq YAML parser pinning.

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

### Commit 2: `write_files/etc/headscale/constants.conf` - Add Matrix-related constants: CONDUIT_LISTEN_PORT (6167), Matrix log rotation settings.

### write_files.etc.headscale.constants.matrix-constants

> **File**: `write_files/etc/headscale/constants.conf`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add Matrix-related constants: CONDUIT_LISTEN_PORT (6167), Matrix log rotation settings.

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

### Commit 3: `write_files/etc/matrix-conduit/conduit.toml.tpl` - Conduit homeserver config template with envsubst variables: MATRIX_SERVER_NAME, MATRIX_REGISTRATION_TOKEN, MATRIX_ALLOW_REGISTRATION, MATRIX_FEDERATION. Binds 127.0.0.1:6167.

### write_files.etc.matrix-conduit.conduit.toml.conduit-config-template

> **File**: `write_files/etc/matrix-conduit/conduit.toml.tpl`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Conduit homeserver config template with envsubst variables: MATRIX_SERVER_NAME, MATRIX_REGISTRATION_TOKEN, MATRIX_ALLOW_REGISTRATION, MATRIX_FEDERATION. Binds 127.0.0.1:6167.

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

### Commit 4: `write_files/etc/systemd/system/conduit.service` - Hardened systemd service unit for Conduit. Matches headscale.service hardening pattern: NoNewPrivileges, ProtectSystem=strict, SystemCallFilter, MemoryDenyWriteExecute.

### write_files.etc.systemd.system.conduit.conduit-systemd-unit

> **File**: `write_files/etc/systemd/system/conduit.service`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Hardened systemd service unit for Conduit. Matches headscale.service hardening pattern: NoNewPrivileges, ProtectSystem=strict, SystemCallFilter, MemoryDenyWriteExecute.

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

### Commit 5: `write_files/etc/headscale/templates/Caddyfile-matrix.tpl` - Caddy reverse proxy template for Matrix: /_matrix/* proxy to :6167, well-known client/server discovery endpoints, JSON access logging.

### write_files.etc.headscale.templates.Caddyfile-matrix.caddy-matrix-template

> **File**: `write_files/etc/headscale/templates/Caddyfile-matrix.tpl`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Caddy reverse proxy template for Matrix: /_matrix/* proxy to :6167, well-known client/server discovery endpoints, JSON access logging.

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

### Commit 6: `write_files/opt/install-matrix.sh` - Matrix install script: creates conduit user, downloads Continuwuity binary with SHA256 verification, creates data/log dirs, enables systemd service. Does NOT open port 8448 (federation off by default).

### write_files.opt.install-matrix.matrix-install-script

> **File**: `write_files/opt/install-matrix.sh`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Matrix install script: creates conduit user, downloads Continuwuity binary with SHA256 verification, creates data/log dirs, enables systemd service. Does NOT open port 8448 (federation off by default).

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

### Commit 7: `write_files/opt/install-yq.sh` - yq install script: downloads mikefarah/yq Go binary with SHA256 verification, installs to /usr/local/bin/yq. Required for YAML config parsing in server-config.

### write_files.opt.install-yq.yq-install-script

> **File**: `write_files/opt/install-yq.sh`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

yq install script: downloads mikefarah/yq Go binary with SHA256 verification, installs to /usr/local/bin/yq. Required for YAML config parsing in server-config.

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

### Commit 8: `write_files/usr/local/bin/server-config` - Unified YAML-driven config wizard. Accepts config via stdin pipe, --config file, or interactive prompts. Parses YAML with yq, extracts all service vars, processes templates via envsubst, writes secrets, restarts services. Covers Headscale, Matrix, SMTP, and security config in one pass.

### write_files.usr.local.bin.unified-config-wizard

> **File**: `write_files/usr/local/bin/server-config`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Unified YAML-driven config wizard. Accepts config via stdin pipe, --config file, or interactive prompts. Parses YAML with yq, extracts all service vars, processes templates via envsubst, writes secrets, restarts services. Covers Headscale, Matrix, SMTP, and security config in one pass.

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

### Commit 9: `write_files/usr/local/bin/matrix-create-bot` - Bot account creation helper using Matrix C-S API /register with registration token. Usage: matrix-create-bot <username> <password>. Outputs access token.

### write_files.usr.local.bin.matrix-bot-creator

> **File**: `write_files/usr/local/bin/matrix-create-bot`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Bot account creation helper using Matrix C-S API /register with registration token. Usage: matrix-create-bot <username> <password>. Outputs access token.

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

### Commit 10: `write_files/etc/fail2ban/filter.d/matrix-auth.conf` - Fail2ban filter for Matrix/Conduit authentication failures. Matches Conduit log patterns for failed login attempts.

### write_files.etc.fail2ban.filter.d.matrix-auth.matrix-fail2ban-filter

> **File**: `write_files/etc/fail2ban/filter.d/matrix-auth.conf`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Fail2ban filter for Matrix/Conduit authentication failures. Matches Conduit log patterns for failed login attempts.

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

### Commit 11: `write_files/etc/fail2ban/jail.d/matrix.conf` - Fail2ban jail for Matrix auth: 5 attempts, 12h ban. Matches existing OIDC jail settings from constants.conf.

### write_files.etc.fail2ban.jail.d.matrix.matrix-fail2ban-jail

> **File**: `write_files/etc/fail2ban/jail.d/matrix.conf`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Fail2ban jail for Matrix auth: 5 attempts, 12h ban. Matches existing OIDC jail settings from constants.conf.

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

### Commit 12: `write_files/etc/logrotate.d/matrix` - Log rotation for /var/log/matrix-conduit/conduit.log. Daily rotation, 7 days retention, matches headscale logrotate pattern.

### write_files.etc.logrotate.d.matrix-logrotate

> **File**: `write_files/etc/logrotate.d/matrix`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Log rotation for /var/log/matrix-conduit/conduit.log. Daily rotation, 7 days retention, matches headscale logrotate pattern.

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

### Commit 13: `config.yaml.example` - Example YAML config document for server-config. Includes all configurable fields with comments: headscale (domain, OIDC), matrix (domain, server_name, federation, registration), smtp (sender, recipient, password), security settings. Users store this in their password manager.

### config.yaml.example-yaml-config

> **File**: `config.yaml.example`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Example YAML config document for server-config. Includes all configurable fields with comments: headscale (domain, OIDC), matrix (domain, server_name, federation, registration), smtp (sender, recipient, password), security settings. Users store this in their password manager.

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

### Commit 14: `write_files.yaml` - Add write_files.yaml entries for all new files: conduit.toml.tpl, conduit.service, Caddyfile-matrix.tpl, install-matrix.sh, install-yq.sh, server-config, matrix-create-bot, fail2ban filter/jail, logrotate.

### write_files.manifest-new-entries

> **File**: `write_files.yaml`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add write_files.yaml entries for all new files: conduit.toml.tpl, conduit.service, Caddyfile-matrix.tpl, install-matrix.sh, install-yq.sh, server-config, matrix-create-bot, fail2ban filter/jail, logrotate.

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

### Commit 15: `cloud-init.yml` - Add two lines to runcmd: /opt/install-yq.sh and /opt/install-matrix.sh. Minimal change to cloud-init.yml.

### cloud-init.runcmd-new-scripts

> **File**: `cloud-init.yml`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add two lines to runcmd: /opt/install-yq.sh and /opt/install-matrix.sh. Minimal change to cloud-init.yml.

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

### Commit 16: `write_files/usr/local/bin/headscale-healthcheck` - Add Conduit health checks: systemd service status, Matrix C-S API responsiveness (GET /_matrix/client/versions on localhost:6167), port 6167 listening.

### write_files.usr.local.bin.healthcheck-matrix

> **File**: `write_files/usr/local/bin/headscale-healthcheck`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Add Conduit health checks: systemd service status, Matrix C-S API responsiveness (GET /_matrix/client/versions on localhost:6167), port 6167 listening.

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

### Commit 17: `setup.sh` - Update manual setup instructions to reference server-config as the new unified entry point alongside legacy headscale-config.

### setup.setup-server-config-ref

> **File**: `setup.sh`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update manual setup instructions to reference server-config as the new unified entry point alongside legacy headscale-config.

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

### Commit 18: `README.md` - Update README: rename identity to Coordination and Relay Server, add Matrix section, document unified YAML config (server-config), update architecture diagram with Matrix endpoints, add config.yaml.example reference, bot account creation docs.

### README.readme-multi-service

> **File**: `README.md`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update README: rename identity to Coordination and Relay Server, add Matrix section, document unified YAML config (server-config), update architecture diagram with Matrix endpoints, add config.yaml.example reference, bot account creation docs.

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
