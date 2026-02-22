# Caddyfile-matrix.tpl - Matrix homeserver reverse proxy
# Generated from template - do not edit directly
# Run 'sudo server-config' to regenerate

${MATRIX_DOMAIN} {
    encode gzip

    # Matrix Client-Server API
    handle /_matrix/* {
        reverse_proxy 127.0.0.1:6167
    }

    log {
        output file /var/log/caddy/matrix-access.log {
            roll_size 10mb
            roll_keep 5
        }
        format json
    }
}
