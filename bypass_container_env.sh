
## These values will override container env variables, and used by entrypoint.sh on every restart. To activate and customize the configurations wanted, remove one or more # sign.

## general
# export Y_LANGUAGE=fr_FR
# export Y_DEBUG=no
# export Y_IGNORE_CONFIG=no
# export Y_PORT_AUTH=1812
# export Y_PORT_ACCT=1813
# export Y_CERT_DAYS=3650
# export Y_CERT_KEEP=yes
# export TZ=Europe/Paris
# export Y_DATE_FORMAT="%Y-%m-%dT%H:%M:%S%z"

## test credentials
# export Y_TEST_NAS=no
# export Y_TEST_NAS_ADDRESS=0.0.0.0/0
# export Y_TEST_NAS_SECRET=Test10203040
# export Y_TEST_USER=no
# export Y_TEST_USER_USERNAME=test
# export Y_TEST_USER_PASSWORD=1234

## mysql db
# export Y_DB_ENABLE=no
# export Y_DB_SERVER=example.com
# export Y_DB_PORT=3306
# export Y_DB_LOGIN=login
# export Y_DB_PASSWORD=password
# export Y_DB_RADIUS_DB=radius
# export Y_DB_TLS_REQUIRED=no
# export Y_DB_READ_CLIENTS=yes
# export Y_DB_AUTHORIZE=yes
# export Y_DB_POSTAUTH=yes
# export Y_DB_ACCOUNTING=yes
# export Y_DB_WAIT=5

## radsec server
# export Y_RADSEC_SERVER_ENABLE=no
# export Y_RADSEC_SERVER_PORT=2083
# export Y_RADSEC_SERVER_TYPE=auth+acct
# export Y_RADSEC_SERVER_CA='${cadir}/ca.pem'
# export Y_RADSEC_SERVER_KEY='${certdir}/server.key'
# export Y_RADSEC_SERVER_KEY_PASSWORD=whatever
# export Y_RADSEC_SERVER_CERT='${certdir}/server.pem'
# export Y_RADSEC_SERVER_CLIENT_IPADDR=0.0.0.0/0
# export Y_RADSEC_SERVER_REQUIRE_CERT=no

## radsec proxy
# export Y_RADSEC_PROXY_ENABLE=no
# export Y_RADSEC_PROXY_CLIENT_IPADDR=0.0.0.0/0
# export Y_RADSEC_PROXY_CLIENT_SECRET=Test50607080
# export Y_RADSEC_PROXY_IPADDR=127.0.0.1
# export Y_RADSEC_PROXY_PORT=2083
# export Y_RADSEC_PROXY_TYPE=auth+acct
# export Y_RADSEC_PROXY_CA='${cadir}/proxy_ca.pem'
# export Y_RADSEC_PROXY_KEY='${certdir}/proxy_client.key'
# export Y_RADSEC_PROXY_KEY_PASSWORD=whatever
# export Y_RADSEC_PROXY_CERT='${certdir}/proxy_client.crt'
