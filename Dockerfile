FROM alpine:latest

LABEL org.opencontainers.image.title="ye3radius"

LABEL org.opencontainers.image.version="2.0.1"
LABEL org.opencontainers.image.created="2025-02-03T15:00:00-03:00"
LABEL org.opencontainers.image.revision="20250203"
LABEL org.opencontainers.image.base.name="ghcr.io/palw3ey/ye3radius:2.0.1"

LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="palw3ey"
LABEL org.opencontainers.image.vendor="palw3ey"
LABEL org.opencontainers.image.maintainer="palw3ey"
LABEL org.opencontainers.image.email="palw3ey@gmail.com"
LABEL org.opencontainers.image.url="https://github.com/palw3ey/ye3radius"
LABEL org.opencontainers.image.documentation="https://github.com/palw3ey/ye3radius/blob/main/README.md"
LABEL org.opencontainers.image.source="https://github.com/palw3ey/ye3radius"
LABEL org.opencontainers.image.description="AAA Radius, RadSec and RadSec Proxy server based on Freeradius and Alpine for SQL DB. GNS3 ready"
LABEL org.opencontainers.image.usage="docker run -dt palw3ey/ye3radius"
LABEL org.opencontainers.image.tip="The folder /etc/raddb is persistent"
LABEL org.opencontainers.image.premiere="20231201"

ENV Y_LANGUAGE=fr_FR \
	Y_DEBUG=no \
	Y_IGNORE_CONFIG=no \
	Y_PORT_AUTH=1812 \
	Y_PORT_ACCT=1813 \
	Y_CERT_DAYS=3650 \
	Y_CERT_KEEP=yes \
  	TZ=Europe/Paris \
	Y_DATE_FORMAT="%Y-%m-%dT%H:%M:%S%z" \
	\
	# test credentials
	Y_TEST_NAS=no \
	Y_TEST_NAS_ADDRESS=0.0.0.0/0 \
	Y_TEST_NAS_SECRET=Test10203040 \
	Y_TEST_USER=no \
	Y_TEST_USER_USERNAME=test \
	Y_TEST_USER_PASSWORD=1234 \
	\
	# mysql db
	Y_DB_ENABLE=no \
	Y_DB_SERVER=example.com \
	Y_DB_PORT=3306 \
	Y_DB_LOGIN=login \
	Y_DB_PASSWORD=password \
	Y_DB_RADIUS_DB=radius \
	Y_DB_TLS_REQUIRED=no \
	Y_DB_READ_CLIENTS=yes \
	Y_DB_AUTHORIZE=yes \
	Y_DB_POSTAUTH=yes \
	Y_DB_ACCOUNTING=yes \
	Y_DB_WAIT=5 \
	\
	# radsec server
	Y_RADSEC_SERVER_ENABLE=no \
	Y_RADSEC_SERVER_PORT=2083 \
	Y_RADSEC_SERVER_TYPE=auth+acct \
	Y_RADSEC_SERVER_CA='${cadir}/ca.pem' \
	Y_RADSEC_SERVER_KEY='${certdir}/server.key' \
	Y_RADSEC_SERVER_KEY_PASSWORD=whatever \
	Y_RADSEC_SERVER_CERT='${certdir}/server.pem' \
	Y_RADSEC_SERVER_CLIENT_IPADDR=0.0.0.0/0 \
	Y_RADSEC_SERVER_REQUIRE_CERT=no \
	\
	# radsec proxy
	Y_RADSEC_PROXY_ENABLE=no \
	Y_RADSEC_PROXY_CLIENT_IPADDR=0.0.0.0/0 \
	Y_RADSEC_PROXY_CLIENT_SECRET=Test50607080 \
	Y_RADSEC_PROXY_IPADDR=127.0.0.1 \
	Y_RADSEC_PROXY_PORT=2083 \
	Y_RADSEC_PROXY_TYPE=auth+acct \
	Y_RADSEC_PROXY_CA='${cadir}/proxy_ca.pem' \
	Y_RADSEC_PROXY_KEY='${certdir}/proxy_client.key' \
	Y_RADSEC_PROXY_KEY_PASSWORD=whatever \
	Y_RADSEC_PROXY_CERT='${certdir}/proxy_client.crt'

ADD entrypoint.sh /

RUN \
	# install packages
	apk --update --no-cache add freeradius freeradius-mysql freeradius-eap freeradius-utils openssl tini tzdata ca-certificates curl ; \
	\
	# clean
	rm -rf /tmp/* && rm -rf /var/cache/apk/* ; \
	\
	# timezone
	cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
	\
    # make executable
    chmod +x /entrypoint.sh
	
ADD i18n/ /i18n/
ADD bypass_container_env.sh /etc/raddb/
ADD default /etc/raddb/sites-available/
ADD radsec_server /etc/raddb/sites-available/
ADD radsec_proxy /etc/raddb/sites-available/
ADD sql /etc/raddb/mods-available/
ADD sqlcounter /etc/raddb/mods-available/
ADD queries.conf /etc/raddb/mods-config/sql/main/mysql/

EXPOSE $Y_PORT_AUTH/udp $Y_PORT_ACCT/udp $Y_RADSEC_SERVER_PORT/tcp

VOLUME /etc/raddb

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]