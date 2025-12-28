# Caddyfile - Reverse proxy for Headscale + Headplane
# Generated from template - do not edit directly
# Run 'sudo headscale-config' to regenerate

${HEADSCALE_DOMAIN} {
    encode gzip
    
    # Headplane admin UI and auth
    handle /admin* {
        reverse_proxy 127.0.0.1:3000 {
            header_up X-Forwarded-Proto https
        }
    }

    # Headplane auth callback
    handle /auth/* {
        reverse_proxy 127.0.0.1:3000 {
            header_up X-Forwarded-Proto https
        }
    }

    # Headscale OIDC endpoints
    handle /oidc/* {
        reverse_proxy 127.0.0.1:8080 {
            header_up X-Forwarded-Proto https
        }
    }
    
    # Headscale API
    handle /api/* {
        reverse_proxy 127.0.0.1:8080
    }
    
    # Headscale noise protocol (Tailscale clients)
    handle /ts2021 {
        reverse_proxy 127.0.0.1:8080
    }
    
    # Headscale machine registration
    handle /machine/* {
        reverse_proxy 127.0.0.1:8080
    }
    
    # Headscale key endpoints
    handle /key {
        reverse_proxy 127.0.0.1:8080
    }
    
    # Headscale register endpoint
    handle /register/* {
        reverse_proxy 127.0.0.1:8080
    }
    
    # Apple device configuration
    handle /apple/* {
        reverse_proxy 127.0.0.1:8080
    }
    
    # Windows device configuration
    handle /windows/* {
        reverse_proxy 127.0.0.1:8080
    }
    
    # Root redirects to Headplane admin
    redir / /admin permanent

    # Structured logging for fail2ban
    log {
        output file /var/log/caddy/access.log {
            roll_size 10mb
            roll_keep 5
        }
        format json
    }
}