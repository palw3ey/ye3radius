FROM alpine:latest

MAINTAINER palw3ey <palw3ey@gmail.com>
LABEL name="ye3radius" version="1.0.0" author="palw3ey" maintainer="palw3ey" email="palw3ey@gmail.com" website="https://github.com/palw3ey/ye3radius" license="MIT" create="20231201" update="20231201" description="A docker AAA Radius server based on Freeradius and Alpine for a MySQL DB. Below 20 Mb. GNS3 ready." usage="docker run -dt palw3ey/ye3radius" tip="The folder /etc/raddb is persistent"
LABEL org.opencontainers.image.source=https://github.com/palw3ey/ye3radius

# general
ENV Y_LANGUAGE=fr_FR \
	Y_DEBUG=no \
	Y_IGNORE_CONFIG=no \
	Y_PORT_AUTH=1812 \
	Y_PORT_ACCT=1813 \
	Y_CERT_DAYS=3650 \
	Y_CERT_KEEP=yes

# test credentials
ENV Y_TEST_NAS=no \
	Y_TEST_NAS_ADDRESS=0.0.0.0/0 \
	Y_TEST_NAS_SECRET=Test10203040 \
	Y_TEST_USER=no \
	Y_TEST_USER_USERNAME=test \
	Y_TEST_USER_PASSWORD=1234

# mysql db
ENV Y_DB_ENABLE=no \
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
	Y_DB_WAIT=5

ADD entrypoint.sh /
ADD i18n/ /i18n/
ADD bypass_docker_env.sh.dis /etc/profile.d/

RUN apk --update --no-cache add freeradius freeradius-mysql freeradius-eap freeradius-utils openssl ; \
	chmod +x /entrypoint.sh

ADD default /etc/raddb/sites-available/
ADD sql /etc/raddb/mods-available/

EXPOSE $Y_PORT_AUTH/udp $Y_PORT_ACCT/udp

VOLUME /etc/raddb

ENTRYPOINT sh --login -c "/entrypoint.sh"
