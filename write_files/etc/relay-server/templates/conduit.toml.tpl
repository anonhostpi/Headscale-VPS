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
