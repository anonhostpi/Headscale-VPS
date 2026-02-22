---
topic: COORDINATION.RELAY.SERVER
phase: discovery
rule: 6
feedback_iteration: 1
baseline_commit: 4b86ed6
last_squashed_commit: null
created: 2026-02-22
branch: feat/matrix-server
worktree: /Users/nick/repos/Headscale-VPS-matrix-server
pr_number: 1
pr_url: https://github.com/anonhostpi/Headscale-VPS/pull/1
pr_state: draft
---

# RESEARCH: Coordination & Relay Server (Rule 6 — Expanded Scope)

## Problem Statement

Expand the Headscale-VPS repo from a single-purpose VPN server into a multi-service
**Coordination and Relay Server** hosting Headscale (VPN) + Matrix (messaging) +
potentially more services. Three major changes:

1. **Add Matrix homeserver** — Conduit/Continuwuity (lightweight, no PostgreSQL)
2. **Rename/repurpose** — "Headscale-VPS" → reflects multi-service purpose
3. **Unified YAML-driven config** — Single YAML document (pipeable from stdin) that
   replaces all interactive config wizards, including security-sensitive values

---

## Rule 6 Context

This is a Rule 6 feedback iteration on the original Rule 0 research. User decisions:

- **Domain questions**: Deferred — everything configurable via the setup wizard
- **Federation**: Private-only (no federation)
- **Registration**: Deferred — configurable via YAML
- **Config wizard**: Unified/integrated (not separate per-service)

New scope added:
- Repo rename from "Headscale-VPS" to multi-service identity
- Unified YAML config document with stdin pipe support
- Security values (passwords, tokens) included in the YAML doc

---

## 1. Matrix Homeserver (Carried Forward from Rule 0)

### Decision: Conduit-family (Continuwuity)

Rationale unchanged from initial research:
- ~32 MB idle RAM vs 200 MB+ for Synapse
- Embedded RocksDB — no PostgreSQL needed
- Static binary install — no Python venv
- Bot SDKs (matrix-nio, matrix-js-sdk) fully compatible

### Updated for User Decisions

- **Federation disabled by default** (`allow_federation = false`). Config YAML can
  override to `true` for users who want it.
- **Registration configurable** — YAML key controls: `disabled`, `token`, or `open`.
  Default: `token` (generates a random registration token for bot account creation).
- **Domain fully configurable** — YAML keys for `matrix.domain` (where Caddy
  listens) and `matrix.server_name` (user ID domain). No hardcoded assumptions.
- **Port 8448 NOT opened by default** since federation is off. Only opened when
  `matrix.federation: true`.

---

## 2. Repo Rename / Repurposing

### Current State

Everything is named `headscale-*`:
- Repo: `Headscale-VPS`
- Scripts: `headscale-config`, `headscale-healthcheck`, `headscale-update`, etc.
- Libraries: `headscale-common.sh`, `headscale-validators.sh`, `headscale-secrets.sh`
- Config paths: `/etc/headscale/`, `/usr/local/bin/headscale-*`, `/usr/local/lib/headscale-*.sh`
- Systemd services: `headscale.service`, `headscale-healthcheck.timer`
- Constants: `/etc/headscale/constants.conf`, `/etc/headscale/versions.conf`

### Rename Scope Assessment

A full rename of every `headscale-*` path, script, and reference is a **massive**
change that touches nearly every file in the repo. It would:
- Break existing deployments that reference `/etc/headscale/` paths
- Require renaming the GitHub repo itself
- Create churn in every script, template, and config file
- Risk introducing bugs from find-and-replace across shell scripts

### Full Rename in This PR

All management scripts and config paths renamed from `headscale-*` to `relay-*`:

| Old | New |
|-----|-----|
| `/etc/headscale/` | `/etc/relay-server/` |
| `/usr/local/lib/headscale-common.sh` | `/usr/local/lib/relay-common.sh` |
| `/usr/local/lib/headscale-validators.sh` | `/usr/local/lib/relay-validators.sh` |
| `/usr/local/lib/headscale-secrets.sh` | `/usr/local/lib/relay-secrets.sh` |
| `/usr/local/bin/headscale-config` | `/usr/local/bin/relay-config` |
| `/usr/local/bin/headscale-healthcheck` | `/usr/local/bin/relay-healthcheck` |
| `/usr/local/bin/headscale-update` | `/usr/local/bin/relay-update` |
| `/usr/local/bin/headscale-rotate-apikey` | `/usr/local/bin/relay-rotate-apikey` |
| `/usr/local/bin/headscale-migrate-secrets` | `/usr/local/bin/relay-migrate-secrets` |
| `/usr/local/bin/headscale-user-setup` | `/usr/local/bin/relay-user-setup` |
| `/usr/local/bin/msmtp-config` | `/usr/local/bin/relay-msmtp-config` |
| `headscale-healthcheck.service` | `relay-healthcheck.service` |
| `headscale-healthcheck.timer` | `relay-healthcheck.timer` |
| `headscale-apikey-check` (cron) | `relay-apikey-check` |
| `headscale.rules` (audit) | `relay-server.rules` |
| `headscale` (logrotate) | `relay-server` |

**NOT renamed** (third-party software / their data paths):
- `headscale` binary and `headscale.service` (the Tailscale control server)
- `headplane.service` (the Headscale web UI)
- `headscale` system user (owns Headscale data)
- `/var/lib/headscale/`, `/var/lib/headplane/` (service data directories)
- `headscale.conf` fail2ban jail (references headscale-specific logs)

New files use the `relay-*` prefix consistently, plus `server-config` for the
unified wizard and `matrix-*` for Matrix-specific tools.

---

## 3. Unified YAML-Driven Config

### Current Config Flow

Three separate interactive wizards with environment variables:

1. **`headscale-config`** — Prompts for domain, Azure OIDC settings, writes
   `/etc/environment.d/headscale.conf`, processes templates via `envsubst`
2. **`msmtp-config`** — Prompts for SMTP email/password, writes `/etc/msmtprc`
3. **`setup.sh`** (manual) — User exports env vars and runs scripts manually

Each wizard has its own `read -p` prompts, its own validation, and its own output
format. There's no single document that captures the full server configuration.

### Design: Unified YAML Config Document

A single YAML document that contains ALL server configuration. The user can:
- **Pipe from stdin**: `cat config.yaml | sudo server-config`
- **Pass as file**: `sudo server-config --config /path/to/config.yaml`
- **Interactive fallback**: If no stdin/file, fall back to interactive prompts
  (preserving backward compatibility)
- **Store in password manager**: The complete YAML includes secrets, so one document
  fully configures the server

### YAML Schema

```yaml
# Coordination & Relay Server Configuration
# Store this in your password manager for full server recovery

# === Headscale VPN ===
headscale:
  domain: vpn.example.com              # Public domain for Headscale
  oidc:
    tenant_id: contoso.onmicrosoft.com  # Azure AD tenant
    client_id: 12345678-...             # Azure app client ID
    client_secret: secret_value         # Azure app client secret
    allowed_email: user@example.com     # Allowed login email

# === Matrix Messaging ===
matrix:
  enabled: true                         # Install and configure Matrix
  domain: matrix.example.com            # Public domain for Matrix
  server_name: example.com              # User ID domain (@user:example.com)
  federation: false                     # Disable federation (private server)
  registration: token                   # disabled | token | open
  registration_token: null              # Auto-generated if null and registration=token
  admin_user: admin                     # First admin username
  admin_password: null                  # Auto-generated if null

# === Email Notifications ===
smtp:
  enabled: true                         # Configure SMTP email
  sender_email: alerts@example.com      # M365 SMTP sender
  recipient_email: admin@example.com    # Where alerts go
  smtp_user: alerts@example.com         # SMTP login (usually same as sender)
  smtp_password: app_password_here      # M365 app password

# === Security ===
security:
  ssh_port: 22                          # SSH port (for firewall rules)
  fail2ban: true                        # Enable fail2ban
```

### YAML Parsing Approach

**Tool: `yq`** — standalone Go binary (mikefarah/yq)

- Downloaded during cloud-init `bootcmd` or early `runcmd` (before config runs)
- Static binary, zero runtime dependencies
- ~20 MB download
- Added to `versions.conf` with SHA256 checksum verification (matching existing
  pattern for NVM, Node.js, Headscale)

**Integration with existing `envsubst` pattern:**

The unified config script:
1. Parses YAML with `yq` to extract values into shell variables
2. Exports those variables for `envsubst` (same as current headscale-config)
3. Processes all templates in one pass (Headscale, Headplane, Caddy, Matrix)

This means templates (`.tpl` files) remain unchanged — they still use `${VAR}`
syntax. The change is upstream: how variables get populated.

```bash
# Example: extract from YAML into env vars
HEADSCALE_DOMAIN=$(yq '.headscale.domain' "$CONFIG_FILE")
AZURE_TENANT_ID=$(yq '.headscale.oidc.tenant_id' "$CONFIG_FILE")
MATRIX_DOMAIN=$(yq '.matrix.domain' "$CONFIG_FILE")
# ... etc

# Then existing envsubst pipeline works unchanged
export HEADSCALE_DOMAIN AZURE_TENANT_ID MATRIX_DOMAIN
envsubst < template.tpl > output.conf
```

### Stdin Pipe Support

```bash
# From password manager or file
cat config.yaml | sudo server-config

# Or directly
sudo server-config --config config.yaml

# Or interactive (no stdin, no file)
sudo server-config
```

Detection logic:
```bash
if [ -n "$CONFIG_FILE" ]; then
  # --config flag provided
  parse_yaml "$CONFIG_FILE"
elif [ ! -t 0 ]; then
  # stdin is not a terminal (piped data)
  cat > /tmp/server-config-input.yaml
  parse_yaml /tmp/server-config-input.yaml
  rm -f /tmp/server-config-input.yaml
else
  # interactive mode — prompt for each value
  prompt_interactive
fi
```

### Backward Compatibility

The existing `headscale-config` and `msmtp-config` scripts remain as-is. The new
`server-config` is an additional unified entry point that calls into the same
template processing and service restart logic.

Users who already deployed with the old scripts don't need to change anything.
The YAML config is a new, optional, better path.

### Secret Handling

Secrets in the YAML (passwords, tokens, client secrets) are:
1. Read from the YAML document
2. Written to their respective secret files (same paths as today)
3. Encrypted via `systemd-creds` (same as today via `encrypt_secret_if_supported`)
4. The original YAML document is NOT stored on the server — it's transient input

The YAML document lives in the user's password manager, not on disk. The
`server-config` script processes it and discards the input.

---

## 4. Integration Design (Updated)

### File Organization

New files follow the existing `write_files/` pattern. New files use `server-*`
naming; existing files keep `headscale-*` naming.

### New Files

| Repo path | Target path | Perms | Purpose |
|-----------|-------------|-------|---------|
| `write_files/opt/install-matrix.sh` | `/opt/install-matrix.sh` | 0755 | Matrix install (binary, user, dirs) |
| `write_files/opt/install-yq.sh` | `/opt/install-yq.sh` | 0755 | yq binary install with checksum |
| `write_files/usr/local/bin/server-config` | `/usr/local/bin/server-config` | 0755 | Unified YAML config wizard |
| `write_files/usr/local/bin/matrix-create-bot` | `/usr/local/bin/matrix-create-bot` | 0755 | Bot account creation helper |
| `write_files/etc/matrix-conduit/conduit.toml.tpl` | `/etc/matrix-conduit/conduit.toml.tpl` | 0644 | Conduit config template |
| `write_files/etc/headscale/templates/Caddyfile-matrix.tpl` | `/etc/headscale/templates/Caddyfile-matrix.tpl` | 0644 | Matrix Caddy config template |
| `write_files/etc/systemd/system/conduit.service` | `/etc/systemd/system/conduit.service` | 0644 | Systemd unit (hardened) |
| `write_files/etc/fail2ban/filter.d/matrix-auth.conf` | `/etc/fail2ban/filter.d/matrix-auth.conf` | 0644 | Fail2ban filter for Matrix |
| `write_files/etc/fail2ban/jail.d/matrix.conf` | `/etc/fail2ban/jail.d/matrix.conf` | 0644 | Fail2ban jail for Matrix |
| `write_files/etc/logrotate.d/matrix` | `/etc/logrotate.d/matrix` | 0644 | Log rotation |
| `config.yaml.example` | (repo root) | — | Example YAML config for docs |

### Modified Files

| Repo path | Change |
|-----------|--------|
| `write_files.yaml` | Add entries for all new files |
| `cloud-init.yml` | Add `install-yq.sh` and `install-matrix.sh` to `runcmd` |
| `write_files/etc/headscale/versions.conf` | Add `CONDUIT_VERSION`, `CONDUIT_SHA256`, `YQ_VERSION`, `YQ_SHA256` |
| `write_files/etc/headscale/constants.conf` | Add Matrix constants |
| `write_files/usr/local/bin/headscale-healthcheck` | Add Conduit service/API checks |
| `README.md` | Update identity, add Matrix docs, add YAML config docs |
| `setup.sh` | Update to reference `server-config` as the new entry point |

### cloud-init.yml Changes (Minimal)

```yaml
runcmd:
  - /opt/setup-headscale.sh
  - /opt/install-headplane.sh
  - /opt/install-yq.sh              # NEW — yq for YAML parsing
  - /opt/install-matrix.sh          # NEW — Matrix/Conduit setup
```

Two lines added. Everything else goes through `write_files/`.

### Config Flow (New Unified Path)

```
User's password manager
    │
    ▼
config.yaml (piped via stdin or --config flag)
    │
    ▼
server-config (parses YAML with yq)
    │
    ├── Extracts Headscale vars ──→ envsubst ──→ headscale.yaml, headplane.yaml
    ├── Extracts Matrix vars ────→ envsubst ──→ conduit.toml
    ├── Extracts SMTP vars ──────→ writes msmtprc, aliases
    ├── Extracts Caddy vars ─────→ envsubst ──→ Caddyfile (merged)
    ├── Writes secrets ──────────→ encrypt_secret_if_supported()
    └── Restarts services ───────→ systemctl restart headscale caddy conduit
```

### Config Flow (Legacy Interactive Path — Preserved)

```
sudo headscale-config     # Still works — prompts for Headscale/OIDC
sudo msmtp-config         # Still works — prompts for SMTP
sudo server-config        # New — interactive mode if no stdin/file
```

---

## 5. Conduit Configuration (Updated)

### Config Template

`/etc/matrix-conduit/conduit.toml.tpl`:

```toml
[global]
server_name = "${MATRIX_SERVER_NAME}"
database_path = "/var/lib/matrix-conduit/"
database_backend = "rocksdb"
port = 6167
address = "127.0.0.1"
max_request_size = 20_000_000
allow_registration = ${MATRIX_ALLOW_REGISTRATION}
registration_token = "${MATRIX_REGISTRATION_TOKEN}"
allow_federation = ${MATRIX_FEDERATION}
trusted_servers = ["matrix.org"]
log = "warn"
```

### Systemd Service (Hardened)

```ini
[Unit]
Description=Conduit Matrix Homeserver
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=conduit
Group=conduit
Environment=CONDUIT_CONFIG=/etc/matrix-conduit/conduit.toml
ExecStart=/usr/local/bin/matrix-conduit
Restart=always
RestartSec=5
StandardOutput=append:/var/log/matrix-conduit/conduit.log
StandardError=append:/var/log/matrix-conduit/conduit.log

# Hardening (matches headscale.service)
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/matrix-conduit /var/log/matrix-conduit
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
SystemCallFilter=@system-service
SystemCallArchitectures=native
PrivateDevices=true
ProtectClock=true
ProtectHostname=true

[Install]
WantedBy=multi-user.target
```

### Caddy Template for Matrix

`/etc/headscale/templates/Caddyfile-matrix.tpl`:

```caddyfile
# Matrix homeserver reverse proxy
${MATRIX_DOMAIN} {
    encode gzip

    # Matrix Client-Server API
    handle /_matrix/* {
        reverse_proxy 127.0.0.1:6167
    }

    # Well-known for client discovery (if server_name differs from domain)
    handle /.well-known/matrix/client {
        respond `{"m.homeserver":{"base_url":"https://${MATRIX_DOMAIN}"}}` 200 {
            header Content-Type application/json
            header Access-Control-Allow-Origin *
        }
    }

    # Well-known for federation discovery
    handle /.well-known/matrix/server {
        respond `{"m.server":"${MATRIX_DOMAIN}:443"}` 200 {
            header Content-Type application/json
        }
    }

    log {
        output file /var/log/caddy/matrix-access.log {
            roll_size 10mb
            roll_keep 5
        }
        format json
    }
}
```

When federation is enabled, an additional block for `:8448` is added dynamically
by `server-config`.

---

## 6. Networking (Updated)

| Port | Protocol | Purpose | Default |
|------|----------|---------|---------|
| 443 | TCP | HTTPS (Headscale + Matrix client API via Caddy) | Open |
| 8448 | TCP | Matrix federation | **Closed** (opened when `matrix.federation: true`) |
| 22 | TCP | SSH | Open |
| 80 | TCP | HTTP → HTTPS redirect | Open |
| 3478 | UDP | STUN (DERP) | Open |

---

## 7. Bot Account Creation

Since Conduit lacks a REST admin API, bot account creation uses the standard Matrix
Client-Server `/register` endpoint with a registration token:

```bash
#!/usr/bin/env bash
# matrix-create-bot — Create a Matrix bot account using registration token

HOMESERVER_URL="https://${MATRIX_DOMAIN}"
TOKEN="${MATRIX_REGISTRATION_TOKEN}"
USERNAME="$1"
PASSWORD="$2"

# Standard Matrix C-S API registration with token
curl -fsSL -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"auth\": {
      \"type\": \"m.login.registration_token\",
      \"token\": \"${TOKEN}\",
      \"session\": \"\"
    },
    \"username\": \"${USERNAME}\",
    \"password\": \"${PASSWORD}\"
  }" \
  "${HOMESERVER_URL}/_matrix/client/v3/register"
```

This works regardless of whether registration is set to `token` or `open`. If
registration is `disabled`, bot accounts must be created via the admin room.

---

## Open Questions (Resolved)

| Question | Resolution |
|----------|-----------|
| User ID format | Configurable via `matrix.server_name` in YAML |
| Matrix domain | Configurable via `matrix.domain` in YAML |
| Registration policy | Configurable; default `token` |
| Federation | Default `false` (private); configurable |
| Separate vs unified config wizard | Unified `server-config` |
| Base domain control | User's responsibility; YAML accepts any domain |

---

## Scope Boundary for This PR

### In Scope
- Matrix homeserver (Conduit/Continuwuity) installation and configuration
- Unified `server-config` script with YAML stdin support
- `yq` binary installation for YAML parsing
- Updated README with multi-service identity
- Example `config.yaml.example` in repo root
- Fail2ban, logrotate, healthcheck for Matrix
- Bot account creation helper

### Out of Scope (Future PRs)
- Full `headscale-*` → generic rename of existing scripts/paths
- GitHub repo rename
- Renaming `/etc/headscale/` filesystem paths
- Deleting legacy `headscale-config` / `msmtp-config` (they remain for backward
  compatibility)

---

## References

- Continuwuity: https://forgejo.ellis.link/continuwuation/continuwuity
- Conduit deployment docs: https://docs.conduit.rs/deploying/generic.html
- mikefarah/yq: https://github.com/mikefarah/yq
- Matrix C-S API /register: https://spec.matrix.org/v1.13/client-server-api/#post_matrixclientv3register
- Agents repo Issue #44: Matrix communication support

---

**Status**: Rule 6 — Discovery complete (feedback iteration 1). Ready for gate review.
