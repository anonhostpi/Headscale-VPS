# PLAN: Coordination & Relay Server — Matrix + Unified Config + Rename

## Overview

Expand Headscale-VPS into a multi-service Coordination & Relay Server:
1. Rename management scripts/paths from `headscale-*` to `relay-*`
2. Add Matrix homeserver (Conduit/Continuwuity)
3. Add unified YAML-driven `server-config` wizard
4. Add `yq` for YAML parsing
5. Update documentation and identity

### Rename Convention

- Management scripts: `headscale-*` → `relay-*` (e.g., `relay-healthcheck`, `relay-config`)
- Config directory: `/etc/headscale/` → `/etc/relay-server/`
- Library files: `headscale-common.sh` → `relay-common.sh`
- The `headscale` **binary** and **systemd service** keep their original names (third-party software)
- The `headscale` **system user** keeps its name (owns Headscale data)

## Commits

<!-- ANNOTATIONS:START -->
<!-- ANNOTATIONS:END -->

### Commit 1: `write_files/usr/local/lib/relay-common.sh` - Rename headscale-common.sh to relay-common.sh. Content unchanged — provides color defs, logging functions, banner printing.

### write_files.usr.local.lib.relay-common.rename-common-lib

> **File**: `write_files/usr/local/lib/headscale-common.sh -> write_files/usr/local/lib/relay-common.sh`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-common.sh to relay-common.sh. Content unchanged — provides color defs, logging functions, banner printing.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 2: `write_files/usr/local/lib/relay-validators.sh` - Rename headscale-validators.sh to relay-validators.sh. Content unchanged — provides domain, email, UUID validation.

### write_files.usr.local.lib.relay-validators.rename-validators-lib

> **File**: `write_files/usr/local/lib/headscale-validators.sh -> write_files/usr/local/lib/relay-validators.sh`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-validators.sh to relay-validators.sh. Content unchanged — provides domain, email, UUID validation.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 3: `write_files/usr/local/lib/relay-secrets.sh` - Rename headscale-secrets.sh to relay-secrets.sh. Update internal path from /etc/headscale/constants.conf to /etc/relay-server/constants.conf. Update comment referencing headscale-common.sh.

### write_files.usr.local.lib.relay-secrets.rename-secrets-lib

> **File**: `write_files/usr/local/lib/headscale-secrets.sh -> write_files/usr/local/lib/relay-secrets.sh`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-secrets.sh to relay-secrets.sh. Update internal path from /etc/headscale/constants.conf to /etc/relay-server/constants.conf. Update comment referencing headscale-common.sh.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 4: `write_files/etc/relay-server/versions.conf` - Move versions.conf from /etc/headscale/ to /etc/relay-server/. Add CONDUIT_VERSION, CONDUIT_SHA256, YQ_VERSION, YQ_SHA256.

### write_files.etc.relay-server.versions.move-versions-conf

> **File**: `write_files/etc/headscale/versions.conf -> write_files/etc/relay-server/versions.conf`
> **Type**: MOVED
> **Commit**: 1 of 1 for this file

#### Description

Move versions.conf from /etc/headscale/ to /etc/relay-server/. Add CONDUIT_VERSION, CONDUIT_SHA256, YQ_VERSION, YQ_SHA256.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | move | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 5: `write_files/etc/relay-server/constants.conf` - Move constants.conf from /etc/headscale/ to /etc/relay-server/. Add Matrix constants: CONDUIT_LISTEN_PORT (6167), MATRIX_FEDERATION_PORT (8448).

### write_files.etc.relay-server.constants.move-constants-conf

> **File**: `write_files/etc/headscale/constants.conf -> write_files/etc/relay-server/constants.conf`
> **Type**: MOVED
> **Commit**: 1 of 1 for this file

#### Description

Move constants.conf from /etc/headscale/ to /etc/relay-server/. Add Matrix constants: CONDUIT_LISTEN_PORT (6167), MATRIX_FEDERATION_PORT (8448).

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | move | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 6: `write_files/etc/relay-server/templates/headscale.yaml.tpl` - Move headscale.yaml.tpl from /etc/headscale/templates/ to /etc/relay-server/templates/. Content unchanged.

### write_files.etc.relay-server.templates.headscale.yaml.move-headscale-tpl

> **File**: `write_files/etc/headscale/templates/headscale.yaml.tpl -> write_files/etc/relay-server/templates/headscale.yaml.tpl`
> **Type**: MOVED
> **Commit**: 1 of 1 for this file

#### Description

Move headscale.yaml.tpl from /etc/headscale/templates/ to /etc/relay-server/templates/. Content unchanged.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | move | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 7: `write_files/etc/relay-server/templates/headplane.yaml.tpl` - Move headplane.yaml.tpl from /etc/headscale/templates/ to /etc/relay-server/templates/. Content unchanged.

### write_files.etc.relay-server.templates.headplane.yaml.move-headplane-tpl

> **File**: `write_files/etc/headscale/templates/headplane.yaml.tpl -> write_files/etc/relay-server/templates/headplane.yaml.tpl`
> **Type**: MOVED
> **Commit**: 1 of 1 for this file

#### Description

Move headplane.yaml.tpl from /etc/headscale/templates/ to /etc/relay-server/templates/. Content unchanged.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | move | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 8: `write_files/etc/relay-server/templates/Caddyfile.tpl` - Move Caddyfile.tpl from /etc/headscale/templates/ to /etc/relay-server/templates/. Content unchanged.

### write_files.etc.relay-server.templates.Caddyfile.move-caddy-tpl

> **File**: `write_files/etc/headscale/templates/Caddyfile.tpl -> write_files/etc/relay-server/templates/Caddyfile.tpl`
> **Type**: MOVED
> **Commit**: 1 of 1 for this file

#### Description

Move Caddyfile.tpl from /etc/headscale/templates/ to /etc/relay-server/templates/. Content unchanged.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | move | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 9: `write_files/usr/local/bin/relay-config` - Rename headscale-config to relay-config. Update source paths: headscale-common.sh→relay-common.sh, headscale-validators.sh→relay-validators.sh, headscale-secrets.sh→relay-secrets.sh. Update TEMPLATES_DIR from /etc/headscale/templates to /etc/relay-server/templates. Update ENV_FILE references.

### write_files.usr.local.bin.rename-config-wizard

> **File**: `write_files/usr/local/bin/headscale-config -> write_files/usr/local/bin/relay-config`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-config to relay-config. Update source paths: headscale-common.sh→relay-common.sh, headscale-validators.sh→relay-validators.sh, headscale-secrets.sh→relay-secrets.sh. Update TEMPLATES_DIR from /etc/headscale/templates to /etc/relay-server/templates. Update ENV_FILE references.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 10: `write_files/usr/local/bin/relay-healthcheck` - Rename headscale-healthcheck to relay-healthcheck. Update constants.conf path to /etc/relay-server/. Add Conduit health checks: systemd service status, Matrix C-S API (GET /_matrix/client/versions on :6167), port 6167.

### write_files.usr.local.bin.rename-healthcheck

> **File**: `write_files/usr/local/bin/headscale-healthcheck -> write_files/usr/local/bin/relay-healthcheck`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-healthcheck to relay-healthcheck. Update constants.conf path to /etc/relay-server/. Add Conduit health checks: systemd service status, Matrix C-S API (GET /_matrix/client/versions on :6167), port 6167.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 11: `write_files/usr/local/bin/relay-update` - Rename headscale-update to relay-update. Update versions.conf path to /etc/relay-server/. Update email subject from 'Headscale VPS' to 'Relay Server'. Headscale binary calls unchanged.

### write_files.usr.local.bin.rename-update-script

> **File**: `write_files/usr/local/bin/headscale-update -> write_files/usr/local/bin/relay-update`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-update to relay-update. Update versions.conf path to /etc/relay-server/. Update email subject from 'Headscale VPS' to 'Relay Server'. Headscale binary calls unchanged.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 12: `write_files/usr/local/bin/relay-rotate-apikey` - Rename headscale-rotate-apikey to relay-rotate-apikey. Update source refs: headscale-common.sh→relay-common.sh, headscale-secrets.sh→relay-secrets.sh.

### write_files.usr.local.bin.rename-rotate-apikey

> **File**: `write_files/usr/local/bin/headscale-rotate-apikey -> write_files/usr/local/bin/relay-rotate-apikey`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-rotate-apikey to relay-rotate-apikey. Update source refs: headscale-common.sh→relay-common.sh, headscale-secrets.sh→relay-secrets.sh.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 13: `write_files/usr/local/bin/relay-migrate-secrets` - Rename headscale-migrate-secrets to relay-migrate-secrets. Update source refs: headscale-common.sh→relay-common.sh, headscale-secrets.sh→relay-secrets.sh. Update banner text.

### write_files.usr.local.bin.rename-migrate-secrets

> **File**: `write_files/usr/local/bin/headscale-migrate-secrets -> write_files/usr/local/bin/relay-migrate-secrets`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-migrate-secrets to relay-migrate-secrets. Update source refs: headscale-common.sh→relay-common.sh, headscale-secrets.sh→relay-secrets.sh. Update banner text.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 14: `write_files/usr/local/bin/relay-user-setup` - Rename headscale-user-setup to relay-user-setup. Update banner text from 'Headscale VPS' to 'Relay Server'.

### write_files.usr.local.bin.rename-user-setup

> **File**: `write_files/usr/local/bin/headscale-user-setup -> write_files/usr/local/bin/relay-user-setup`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-user-setup to relay-user-setup. Update banner text from 'Headscale VPS' to 'Relay Server'.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 15: `write_files/usr/local/bin/relay-msmtp-config` - Rename msmtp-config to relay-msmtp-config for naming consistency. Update source refs: headscale-common.sh→relay-common.sh, headscale-validators.sh→relay-validators.sh, headscale-secrets.sh→relay-secrets.sh.

### write_files.usr.local.bin.rename-msmtp-config

> **File**: `write_files/usr/local/bin/msmtp-config -> write_files/usr/local/bin/relay-msmtp-config`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename msmtp-config to relay-msmtp-config for naming consistency. Update source refs: headscale-common.sh→relay-common.sh, headscale-validators.sh→relay-validators.sh, headscale-secrets.sh→relay-secrets.sh.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 16: `write_files/etc/systemd/system/relay-healthcheck.service` - Rename headscale-healthcheck.service to relay-healthcheck.service. Update ExecStart to /usr/local/bin/relay-healthcheck. Update Description and SyslogIdentifier.

### write_files.etc.systemd.system.relay-healthcheck.rename-hc-service

> **File**: `write_files/etc/systemd/system/headscale-healthcheck.service -> write_files/etc/systemd/system/relay-healthcheck.service`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-healthcheck.service to relay-healthcheck.service. Update ExecStart to /usr/local/bin/relay-healthcheck. Update Description and SyslogIdentifier.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 17: `write_files/etc/systemd/system/relay-healthcheck.timer` - Rename headscale-healthcheck.timer to relay-healthcheck.timer. Update Description.

### write_files.etc.systemd.system.relay-healthcheck.rename-hc-timer

> **File**: `write_files/etc/systemd/system/headscale-healthcheck.timer -> write_files/etc/systemd/system/relay-healthcheck.timer`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-healthcheck.timer to relay-healthcheck.timer. Update Description.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 18: `write_files/etc/cron.weekly/relay-apikey-check` - Rename headscale-apikey-check to relay-apikey-check. Update script reference from headscale-rotate-apikey to relay-rotate-apikey.

### write_files.etc.cron.weekly.rename-cron-apikey

> **File**: `write_files/etc/cron.weekly/headscale-apikey-check -> write_files/etc/cron.weekly/relay-apikey-check`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale-apikey-check to relay-apikey-check. Update script reference from headscale-rotate-apikey to relay-rotate-apikey.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 19: `write_files/etc/audit/rules.d/relay-server.rules` - Rename headscale.rules to relay-server.rules. Update audit key names. Add Matrix data directory watch.

### write_files.etc.audit.rules.d.relay-server.rename-audit-rules

> **File**: `write_files/etc/audit/rules.d/headscale.rules -> write_files/etc/audit/rules.d/relay-server.rules`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale.rules to relay-server.rules. Update audit key names. Add Matrix data directory watch.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 20: `write_files/etc/logrotate.d/relay-server` - Rename headscale logrotate to relay-server. Add Matrix conduit.log rotation alongside existing headscale logs.

### write_files.etc.logrotate.d.rename-logrotate

> **File**: `write_files/etc/logrotate.d/headscale -> write_files/etc/logrotate.d/relay-server`
> **Type**: RENAMED
> **Commit**: 1 of 1 for this file

#### Description

Rename headscale logrotate to relay-server. Add Matrix conduit.log rotation alongside existing headscale logs.

#### Diff

```diff
placeholder
```

#### Rule Compliance

> See Operating Procedures for Rules 3-4

| Rule | Check | Status |
|------|-------|--------|
| **Rule 3: Lines** | 0 lines | PASS |
| **Rule 3: Exempt** | rename | EXEMPT |
| **Rule 4: Atomic** | Single logical unit | YES |

### Commit 21: `write_files/opt/setup-headscale.sh` - Update internal references: /etc/headscale/versions.conf → /etc/relay-server/versions.conf. Update /etc/headscale/templates → /etc/relay-server/templates. Update healthcheck timer name to relay-healthcheck.timer.

### write_files.opt.setup-headscale.update-setup-refs

> **File**: `write_files/opt/setup-headscale.sh`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update internal references: /etc/headscale/versions.conf → /etc/relay-server/versions.conf. Update /etc/headscale/templates → /etc/relay-server/templates. Update healthcheck timer name to relay-healthcheck.timer.

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

### Commit 22: `write_files/opt/install-headplane.sh` - Update source path: /etc/headscale/versions.conf → /etc/relay-server/versions.conf.

### write_files.opt.install-headplane.update-headplane-refs

> **File**: `write_files/opt/install-headplane.sh`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update source path: /etc/headscale/versions.conf → /etc/relay-server/versions.conf.

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

### Commit 23: `write_files/etc/systemd/system/headscale.service` - No rename (third-party service). Content unchanged — headscale.service keeps its name and paths since they reference the headscale binary and its data.

### write_files.etc.systemd.system.headscale.update-hs-service-paths

> **File**: `write_files/etc/systemd/system/headscale.service`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

No rename (third-party service). Content unchanged — headscale.service keeps its name and paths since they reference the headscale binary and its data.

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

### Commit 24: `write_files/etc/systemd/system/headplane.service` - No rename (Headplane service). Content unchanged — headplane.service keeps its name. Paths reference headscale data owned by headscale user.

### write_files.etc.systemd.system.headplane.update-hp-service-paths

> **File**: `write_files/etc/systemd/system/headplane.service`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

No rename (Headplane service). Content unchanged — headplane.service keeps its name. Paths reference headscale data owned by headscale user.

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

### Commit 25: `write_files/etc/fail2ban/jail.d/headscale.conf` - No rename — this jail is specifically for the headscale authkey service. Content unchanged since it references headscale log paths.

### write_files.etc.fail2ban.jail.d.headscale.update-f2b-headscale-jail

> **File**: `write_files/etc/fail2ban/jail.d/headscale.conf`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

No rename — this jail is specifically for the headscale authkey service. Content unchanged since it references headscale log paths.

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

### Commit 26: `write_files/etc/matrix-conduit/conduit.toml.tpl` - Conduit homeserver config template. envsubst vars: MATRIX_SERVER_NAME, MATRIX_REGISTRATION_TOKEN, MATRIX_ALLOW_REGISTRATION, MATRIX_FEDERATION. Binds 127.0.0.1:6167.

### write_files.etc.matrix-conduit.conduit.toml.conduit-config-template

> **File**: `write_files/etc/matrix-conduit/conduit.toml.tpl`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Conduit homeserver config template. envsubst vars: MATRIX_SERVER_NAME, MATRIX_REGISTRATION_TOKEN, MATRIX_ALLOW_REGISTRATION, MATRIX_FEDERATION. Binds 127.0.0.1:6167.

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

### Commit 27: `write_files/etc/systemd/system/conduit.service` - Hardened systemd service for Conduit. Matches headscale.service hardening: NoNewPrivileges, ProtectSystem=strict, SystemCallFilter, MemoryDenyWriteExecute. Logs to /var/log/matrix-conduit/.

### write_files.etc.systemd.system.conduit.conduit-systemd-unit

> **File**: `write_files/etc/systemd/system/conduit.service`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Hardened systemd service for Conduit. Matches headscale.service hardening: NoNewPrivileges, ProtectSystem=strict, SystemCallFilter, MemoryDenyWriteExecute. Logs to /var/log/matrix-conduit/.

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

### Commit 28: `write_files/etc/relay-server/templates/Caddyfile-matrix.tpl` - Caddy reverse proxy template for Matrix: /_matrix/* to :6167, well-known client/server discovery, JSON logging.

### write_files.etc.relay-server.templates.Caddyfile-matrix.caddy-matrix-template

> **File**: `write_files/etc/relay-server/templates/Caddyfile-matrix.tpl`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Caddy reverse proxy template for Matrix: /_matrix/* to :6167, well-known client/server discovery, JSON logging.

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

### Commit 29: `write_files/opt/install-matrix.sh` - Install script: create conduit user, download Continuwuity binary with SHA256 verification from versions.conf, create data/log dirs, enable systemd service. No port 8448 (federation off by default).

### write_files.opt.install-matrix.matrix-install-script

> **File**: `write_files/opt/install-matrix.sh`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Install script: create conduit user, download Continuwuity binary with SHA256 verification from versions.conf, create data/log dirs, enable systemd service. No port 8448 (federation off by default).

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

### Commit 30: `write_files/usr/local/bin/matrix-create-bot` - Bot account creation via Matrix C-S API /register with registration token. Usage: matrix-create-bot <username> <password>. Reads MATRIX_DOMAIN and MATRIX_REGISTRATION_TOKEN from /etc/environment.d/relay-server.conf.

### write_files.usr.local.bin.matrix-bot-creator

> **File**: `write_files/usr/local/bin/matrix-create-bot`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Bot account creation via Matrix C-S API /register with registration token. Usage: matrix-create-bot <username> <password>. Reads MATRIX_DOMAIN and MATRIX_REGISTRATION_TOKEN from /etc/environment.d/relay-server.conf.

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

### Commit 31: `write_files/etc/fail2ban/filter.d/matrix-auth.conf` - Fail2ban filter for Matrix/Conduit auth failures. Matches Conduit log patterns for failed login attempts.

### write_files.etc.fail2ban.filter.d.matrix-auth.matrix-fail2ban-filter

> **File**: `write_files/etc/fail2ban/filter.d/matrix-auth.conf`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Fail2ban filter for Matrix/Conduit auth failures. Matches Conduit log patterns for failed login attempts.

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

### Commit 32: `write_files/etc/fail2ban/jail.d/matrix.conf` - Fail2ban jail for Matrix auth: 5 attempts, 12h ban. Matches existing OIDC jail pattern.

### write_files.etc.fail2ban.jail.d.matrix.matrix-fail2ban-jail

> **File**: `write_files/etc/fail2ban/jail.d/matrix.conf`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Fail2ban jail for Matrix auth: 5 attempts, 12h ban. Matches existing OIDC jail pattern.

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

### Commit 33: `write_files/opt/install-yq.sh` - Install yq (mikefarah/yq) Go binary with SHA256 verification. Reads version/hash from /etc/relay-server/versions.conf. Installs to /usr/local/bin/yq.

### write_files.opt.install-yq.yq-install-script

> **File**: `write_files/opt/install-yq.sh`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Install yq (mikefarah/yq) Go binary with SHA256 verification. Reads version/hash from /etc/relay-server/versions.conf. Installs to /usr/local/bin/yq.

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

### Commit 34: `write_files/usr/local/bin/server-config` - Unified YAML-driven config wizard. Accepts stdin pipe, --config file, or interactive prompts. Uses yq to parse YAML, extracts vars for all services (Headscale, Matrix, SMTP), processes templates via envsubst, writes secrets via relay-secrets.sh, restarts services.

### write_files.usr.local.bin.unified-config-wizard

> **File**: `write_files/usr/local/bin/server-config`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Unified YAML-driven config wizard. Accepts stdin pipe, --config file, or interactive prompts. Uses yq to parse YAML, extracts vars for all services (Headscale, Matrix, SMTP), processes templates via envsubst, writes secrets via relay-secrets.sh, restarts services.

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

### Commit 35: `config.yaml.example` - Example YAML config for server-config. All configurable fields with comments: headscale (domain, OIDC), matrix (domain, server_name, federation, registration), smtp (sender, recipient, password). Users store in password manager.

### config.yaml.example-yaml-config

> **File**: `config.yaml.example`
> **Type**: NEW
> **Commit**: 1 of 1 for this file

#### Description

Example YAML config for server-config. All configurable fields with comments: headscale (domain, OIDC), matrix (domain, server_name, federation, registration), smtp (sender, recipient, password). Users store in password manager.

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

### Commit 36: `write_files.yaml` - Full rewrite of write_files.yaml manifest. Update all renamed paths (headscale→relay-server, headscale-*→relay-*). Add all new Matrix and config files. Remove old paths.

### write_files.manifest-full-update

> **File**: `write_files.yaml`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Full rewrite of write_files.yaml manifest. Update all renamed paths (headscale→relay-server, headscale-*→relay-*). Add all new Matrix and config files. Remove old paths.

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

### Commit 37: `cloud-init.yml` - Update header comment. Change write_files.yaml parser to use new /etc/relay-server/ paths. Add install-yq.sh and install-matrix.sh to runcmd. Update runcmd setup script name if changed.

### cloud-init.cloudinit-updates

> **File**: `cloud-init.yml`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update header comment. Change write_files.yaml parser to use new /etc/relay-server/ paths. Add install-yq.sh and install-matrix.sh to runcmd. Update runcmd setup script name if changed.

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

### Commit 38: `setup.sh` - Update manual setup instructions: headscale-user-setup→relay-user-setup, headscale-config→server-config, headscale-*→relay-* references.

### setup.setup-script-update

> **File**: `setup.sh`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update manual setup instructions: headscale-user-setup→relay-user-setup, headscale-config→server-config, headscale-*→relay-* references.

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

### Commit 39: `README.md` - Update identity to Coordination and Relay Server. Add Matrix section. Document unified YAML config (server-config). Update architecture diagram with Matrix endpoints. Update all script references to relay-* names. Add config.yaml.example docs.

### README.readme-full-rewrite

> **File**: `README.md`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update identity to Coordination and Relay Server. Add Matrix section. Document unified YAML config (server-config). Update architecture diagram with Matrix endpoints. Update all script references to relay-* names. Add config.yaml.example docs.

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

### Commit 40: `write_files/etc/ssh/sshd_config.d/99-hardening.conf` - Update comment referencing headscale-user-setup to relay-user-setup.

### write_files.etc.ssh.sshd_config.d.99-hardening.update-ssh-comment

> **File**: `write_files/etc/ssh/sshd_config.d/99-hardening.conf`
> **Type**: MODIFIED
> **Commit**: 1 of 1 for this file

#### Description

Update comment referencing headscale-user-setup to relay-user-setup.

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
