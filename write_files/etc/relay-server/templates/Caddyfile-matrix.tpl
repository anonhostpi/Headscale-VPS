# Caddyfile-matrix.tpl - Matrix homeserver reverse proxy
# Generated from template - do not edit directly
# Run 'sudo server-config' to regenerate

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
