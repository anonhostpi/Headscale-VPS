---
topic: MATRIX.HOMESERVER.VPS.DEPLOYMENT
phase: discovery
rule: 0
feedback_iteration: 0
baseline_commit: 4b86ed6
last_squashed_commit: null
created: 2026-02-22
branch: feat/matrix-server
worktree: /Users/nick/repos/Headscale-VPS-matrix-server
pr_number: null
pr_url: null
pr_state: null
---

# RESEARCH: Matrix Homeserver for Headscale VPS

## Problem Statement

Add a Matrix homeserver to the existing Headscale-VPS deployment. The server must
be lightweight (VPS already runs Headscale + Headplane + Caddy + Node.js), support
bot account creation for agent use (per Agents repo Issue #44), federate with the
public Matrix network, and integrate with the existing cloud-init / `write_files`
/ `setup.sh` deployment pattern.

---

## Existing Repo Pattern Analysis

The Headscale-VPS repo deploys via cloud-init with this flow:

1. **`cloud-init.yml`** — `bootcmd` clones the repo, reads `write_files.yaml` as
   a manifest, copies files from `write_files/` to their target paths with correct
   permissions. Then `runcmd` runs setup scripts.

2. **`write_files.yaml`** — Flat manifest: `path` + `permissions` pairs. Files in
   `write_files/` mirror the filesystem layout (e.g., `write_files/etc/caddy/...`
   maps to `/etc/caddy/...`).

3. **`write_files/opt/setup-headscale.sh`** — Main setup script run by cloud-init
   `runcmd`. Creates users, installs packages (Caddy, Headscale), sets up firewall,
   enables systemd services.

4. **`write_files/opt/install-headplane.sh`** — Secondary install script run after
   setup. Builds Headplane from source (NVM, Node.js, pnpm).

5. **`write_files/usr/local/bin/headscale-config`** — Interactive config wizard run
   post-deploy. Prompts for domain/OIDC values, processes templates via `envsubst`,
   restarts services.

6. **Templates** in `write_files/etc/headscale/templates/` — `envsubst`-processed
   `.tpl` files for Headscale config, Headplane config, and Caddyfile.

**Key principle:** `cloud-init.yml` should be changed minimally. New services should
be added via `write_files/` and new scripts, not by expanding cloud-init.yml.

---

## Candidate Comparison: Conduit-family vs Synapse

### Resource Requirements

| | Conduit-family | Synapse |
|---|---|---|
| **Idle RAM** | ~32 MB | 200–500 MB+ |
| **Steady-state RAM** | < 200 MB (small server) | 512 MB – 2 GB |
| **Database** | Embedded RocksDB (no external DB) | Requires PostgreSQL (~100 MB extra) |
| **Runtime deps** | None (static musl binary) | Python 3.x, build-essential, libffi, etc. |
| **Config complexity** | ~30-line TOML | 100+ line YAML |
| **Install method** | `wget` + `chmod +x` | Python venv + pip install + Postgres setup |

### Admin API (Bot Account Creation)

| | Conduit-family | Synapse |
|---|---|---|
| **Admin interface** | Chat commands in `#admins` room | Full REST API at `/_synapse/admin/` |
| **Programmatic user creation** | Via Matrix client (matrix-nio) | Via `curl`/HTTP (`registration_shared_secret`) |
| **Automation friendliness** | Workable but requires a Matrix client | Fully scriptable with shell tools |

### Bot SDK Compatibility

Both work with matrix-nio (Python), matrix-js-sdk (JS), and matrix-bot-sdk (TS).
The client-server API is standardized; any spec-compliant homeserver works.

### Federation & Stability

| | Conduit-family | Synapse |
|---|---|---|
| **Federation** | Works; occasional edge cases with very large rooms | Reference implementation; excellent |
| **Project risk** | Community fork chain (Conduit → conduwuit → Continuwuity) | Element-backed; stable |
| **Maturity** | Good for small servers | Production-grade since ~2014 |

---

## Recommendation: Conduit-family (Continuwuity)

**Rationale:**

1. **Resource fit:** 32–200 MB RAM vs 200 MB–2 GB. On a VPS already running 4
   services, this is the deciding factor.

2. **No PostgreSQL:** Eliminates an entire service + 100 MB RAM + operational
   complexity. The embedded RocksDB database is zero-maintenance.

3. **Trivial install:** Single static binary. No Python venv, no build tools, no
   pip. Matches the repo's pattern of downloading binaries and configuring them
   (like the Headscale `.deb` install).

4. **Bot SDKs work:** matrix-nio and matrix-js-sdk are fully compatible.

**Accepted tradeoff:** No REST admin API. Bot accounts are created via admin room
commands (one-time manual step or a thin matrix-nio automation script). For the
agent use case (a few bot accounts, created once), this is acceptable.

**Fork choice:** Continuwuity — the actively maintained community fork as of 2026.
Original Conduit and conduwuit are no longer active.

---

## Integration Design

### Networking

| Port | Protocol | Purpose | Status |
|------|----------|---------|--------|
| 443 | TCP | Client-Server API (via existing Caddy) | Already open |
| 8448 | TCP | Matrix federation (server-to-server) | **New — add to UFW** |

Internally, Conduit listens on `127.0.0.1:6167` (HTTP). Caddy terminates TLS and
proxies `/_matrix/*` to it.

### Caddy Integration

The existing Caddyfile template (`Caddyfile.tpl`) handles `${HEADSCALE_DOMAIN}`.
Matrix needs additional Caddy blocks for:

1. **Matrix subdomain** (`matrix.${HEADSCALE_DOMAIN}`) — proxies `/_matrix/*` to
   Conduit on `:6167`
2. **Federation port** — Caddy also listens on `:8448` for server-to-server traffic
3. **Well-known delegation** (optional) — if user IDs should be
   `@user:example.com` instead of `@user:matrix.example.com`, serve well-known
   files from the base domain

**Approach:** Add a new Caddyfile template (`Caddyfile-matrix.tpl`) that Caddy
imports, rather than bloating the existing `Caddyfile.tpl`. Caddy supports
`import` directives for modular configs.

### Setup Flow Integration

The Matrix setup should be a separate install script (`/opt/install-matrix.sh`)
called from cloud-init `runcmd`, following the same pattern as
`install-headplane.sh`:

```
runcmd:
  - /opt/setup-headscale.sh
  - /opt/install-headplane.sh
  - /opt/install-matrix.sh          # NEW
```

The install script handles:
1. Create `conduit` system user
2. Download Continuwuity binary (with checksum verification)
3. Create `/var/lib/matrix-conduit/` data directory
4. Enable the systemd service (don't start — needs config)
5. Open firewall port 8448

### Configuration Flow Integration

A new config script (`/usr/local/bin/matrix-config`) or extension to the existing
`headscale-config` wizard handles:
1. Prompt for Matrix domain (default: `matrix.${HEADSCALE_DOMAIN}`)
2. Prompt for server_name (user ID domain — the base domain or subdomain)
3. Set registration policy (token-gated or closed)
4. Generate registration token (if token-gated)
5. Process Conduit config template via `envsubst`
6. Process Matrix Caddyfile template
7. Reload Caddy and start Conduit
8. Create initial admin user

### Bot Account Provisioning

A helper script (`/usr/local/bin/matrix-create-bot`) for the one-time bot account
setup. Since Conduit has no REST admin API, this script either:
- **Option A:** Uses `curl` to hit the Matrix client-server registration endpoint
  (if registration is enabled/token-gated)
- **Option B:** Prints instructions for the admin to create accounts via the
  `#admins` room

For the agent use case, Option A with a registration token is cleanest: the script
calls the standard Matrix `/register` endpoint with the token.

---

## Files to Create (in `write_files/` pattern)

### New Files

| Repo path | Target path | Permissions | Purpose |
|-----------|-------------|-------------|---------|
| `write_files/opt/install-matrix.sh` | `/opt/install-matrix.sh` | 0755 | Install script (binary download, user creation, firewall) |
| `write_files/usr/local/bin/matrix-config` | `/usr/local/bin/matrix-config` | 0755 | Post-deploy config wizard |
| `write_files/usr/local/bin/matrix-create-bot` | `/usr/local/bin/matrix-create-bot` | 0755 | Bot account creation helper |
| `write_files/etc/matrix-conduit/conduit.toml.tpl` | `/etc/matrix-conduit/conduit.toml.tpl` | 0644 | Conduit config template |
| `write_files/etc/headscale/templates/Caddyfile-matrix.tpl` | `/etc/headscale/templates/Caddyfile-matrix.tpl` | 0644 | Matrix Caddy config template |
| `write_files/etc/systemd/system/conduit.service` | `/etc/systemd/system/conduit.service` | 0644 | Systemd unit (hardened) |
| `write_files/etc/fail2ban/filter.d/matrix-auth.conf` | `/etc/fail2ban/filter.d/matrix-auth.conf` | 0644 | Fail2ban filter for Matrix auth |
| `write_files/etc/fail2ban/jail.d/matrix.conf` | `/etc/fail2ban/jail.d/matrix.conf` | 0644 | Fail2ban jail for Matrix |
| `write_files/etc/logrotate.d/matrix` | `/etc/logrotate.d/matrix` | 0644 | Log rotation config |

### Modified Files

| Repo path | Change |
|-----------|--------|
| `write_files.yaml` | Add entries for all new files above |
| `cloud-init.yml` | Add `/opt/install-matrix.sh` to `runcmd` |
| `write_files/etc/headscale/versions.conf` | Add `CONDUIT_VERSION` and `CONDUIT_SHA256` |
| `write_files/etc/headscale/constants.conf` | Add Matrix-related constants |
| `write_files/usr/local/bin/headscale-healthcheck` | Add Conduit health check |
| `README.md` | Document Matrix server setup |

### Minimal `cloud-init.yml` Change

Only one line added to `runcmd`:

```yaml
runcmd:
  - /opt/setup-headscale.sh
  - /opt/install-headplane.sh
  - /opt/install-matrix.sh          # NEW
```

---

## Conduit Configuration Template

`/etc/matrix-conduit/conduit.toml.tpl`:

```toml
[global]
server_name = "${MATRIX_SERVER_NAME}"
database_path = "/var/lib/matrix-conduit/"
database_backend = "rocksdb"
port = 6167
address = "127.0.0.1"
max_request_size = 20_000_000
allow_registration = false
registration_token = "${MATRIX_REGISTRATION_TOKEN}"
allow_federation = true
trusted_servers = ["matrix.org"]
log = "warn"
```

---

## Systemd Service (Hardened)

Following the repo's existing hardening patterns from `headscale.service`:

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

# Logging
StandardOutput=append:/var/log/matrix-conduit/conduit.log
StandardError=append:/var/log/matrix-conduit/conduit.log

# Hardening (matches headscale.service pattern)
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

---

## Open Questions for User

1. **User ID format:** `@user:example.com` (requires well-known delegation on
   base domain) vs `@user:matrix.example.com` (simpler, self-contained)?

2. **Matrix domain:** Should the Matrix server be at `matrix.<headscale-domain>`
   (e.g., `matrix.vpn.example.com`), or a different subdomain?

3. **Registration policy:** Token-gated (generates a one-time token for bot
   account creation) or fully closed (admin creates accounts via admin room)?

4. **Federation:** Enable federation with public Matrix network, or keep it
   private/closed?

5. **Separate config wizard:** Should `matrix-config` be a standalone script, or
   should it be integrated into the existing `headscale-config` wizard?

---

## References

- Continuwuity: https://forgejo.ellis.link/continuwuation/continuwuity
- Conduit deployment docs: https://docs.conduit.rs/deploying/generic.html
- Caddy config for Conduit: https://tomfos.tr/matrix/continuwuity/reverse-proxies/caddy/
- Agents repo Issue #44: Matrix communication support
- Matrix federation tester: https://federationtester.matrix.org/
- Matrix Client-Server spec: https://spec.matrix.org/unstable/client-server-api/

---

**Status**: Rule 0 — Discovery complete. Ready for Rule 1 planning.
