# ye3radius

AAA Radius, RadSec and RadSec Proxy server based on Freeradius and Alpine for SQL DB. GNS3 ready

The /etc/raddb folder is persistent.

# Simple usage

```bash
docker run -dt --name myradius -e Y_TEST_NAS=yes -e Y_TEST_USER=yes -p 1812-1813:1812-1813/udp docker.io/palw3ey/ye3radius
```

# Usage with MariaDB 

If you don't have a MariaDB or MySQL Server, then proceed to step 1.  
If you already have a running SQL Server, then skip to step 3.  
If you already have a Radius DB with data, then skip to step 7.  

1. Create MariaDB container
```bash
docker run -dt --name mymariadb -e MYSQL_ROOT_PASSWORD=mypass mariadb:latest
```

2. Create Radius database and Radius DB user
```bash
docker exec -it mymariadb mariadb --user=root --password=mypass
```
```sql
create database radius;
create user 'radiusDBuser'@'%' identified by 'radiusDBpassword';
GRANT ALL PRIVILEGES ON radius.* TO radiusDBuser;
quit;
```

3. Import the MySQL schema
```bash
# install mariadb-client-core
sudo apt install mariadb-client-core -y

# get mymariadb container ip adress
mymariadb_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' mymariadb)

wget https://github.com/palw3ey/ye3radius/raw/main/schema.sql
mariadb --host=$mymariadb_ip --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius < schema.sql
mariadb --host=$mymariadb_ip --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "SHOW TABLES;"
```

4. Create a NAS client  
The nas_address, below, is the IP address of the host that is requesting authentication. Use 0.0.0.0/0 to allow any IP address.
```bash
nas_address="10.10.10.10"
nas_secret="strongSecret"
mariadb --host=$mymariadb_ip --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "INSERT INTO  nas (nasname,shortname,type,ports,secret,server,community,description) VALUES ('"$nas_address"', 'nas access sql', 'other',NULL ,'"$nas_secret"',NULL ,NULL ,'RADIUS Client');"
```

5. Create a user
```bash
employee_username="tux"
employee_password="strongPassword"
mariadb --host=$mymariadb_ip --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "INSERT INTO radcheck (username, attribute, op, value) VALUES ('"$employee_username"', 'Cleartext-Password', ':=', '"$employee_password"');"
```

6. Include AVPair Reply  (optional)  
To include Cisco-AVPair for a user
```bash
mariadb --host=$mymariadb_ip --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius
```
```sql
INSERT INTO radreply
  (username, attribute, op, value)
VALUES
  ('tux', 'cisco-avpair', '+=', 'ipsec:dns-servers=1.1.1.1 8.8.8.8'),
  ('tux', 'cisco-avpair', '+=', 'ipsec:default-domain=example.lan');
quit;
```

7. Run  
In the first run the ye3radius container will creates certificates if not exist, this may take a couple of seconds or minutes before the Radius service get ready
```bash
docker run -dt --name myradius -e Y_DB_ENABLE=yes -e Y_DB_SERVER=example.lan -e Y_DB_PORT=3306 -e Y_DB_LOGIN=radiusDBuser -e Y_DB_PASSWORD=radiusDBpassword -e Y_DB_TLS_REQUIRED=no palw3ey/ye3radius
```

8. Test
```bash
# check if container is ready :
docker logs myradius

# get container IP :
container_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' myradius)

# On a ubuntu host :
apt install freeradius-utils
radtest $employee_username $employee_password $container_ip:1812 0 $nas_secret -x
```

# Test

on the host
```bash
docker exec -it myradius radtest test 1234 localhost:1812 0 testing123 -x
```

on Cisco IOS
```
configure terminal
aaa new-model
radius server ye3radius
  address ipv4 10.10.10.250 auth-port 1812 acct-port 1813
  key strongSecret
  exit
do test aaa group radius server name ye3radius test 1234 new-code
```

# HOWTOs
- Show freeradius log
```bash
docker exec -it myradius tail -f /var/log/radius/radius.log
# To exit : Ctrl C
```

- Connect to DB
```bash
mysql --host=example.com --port=3306 --user=login --password=password --database=radius
```

- Add a user
```sql
INSERT INTO radcheck
	(username, attribute, op, value)
VALUES
	('user', 'Cleartext-Password', ':=', 'password');
```

- Delete a user
```sql
DELETE FROM radcheck
WHERE username = 'user';
```

- Update a user password
```sql
UPDATE radcheck
SET value='password'
WHERE username='user';
```

- Disable a user
```sql
INSERT INTO radcheck
	(username, attribute, op, value)
VALUES
	('user', 'Auth-Type', ':=', 'Reject');
```

- Enable a previously disabled user
```sql
DELETE FROM radcheck
WHERE username='user'
AND attribute='Auth-Type'
AND value='Reject';
```

- List all user
```sql
SELECT * FROM radcheck;
```

- Add user to group
```sql
INSERT INTO radusergroup (username, groupname) VALUES ('tux', 'Manager');
```

- Add the Class attribute in the response, for group membership
```sql
INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES ('Manager', 'Class', ':=', 'Manager');
```

- Enable RadSec Server
```bash
# just add : -e Y_RADSEC_SERVER_ENABLE=yes
docker run -dt --name myradius \
	-e Y_DB_ENABLE=yes -e Y_DB_SERVER=example.lan -e Y_DB_PORT=3306 -e Y_DB_TLS_REQUIRED=no \
	-e Y_DB_LOGIN=radiusDBuser -e Y_DB_PASSWORD=radiusDBpassword \
	-e Y_RADSEC_SERVER_ENABLE=yes \
	-p 2083:2083/tcp \
	palw3ey/ye3radius
```

- Create a Radius Proxy linked to a RadSec Server
```bash
# get the client key, certificate and ca in the Remote RadSec Server
(docker exec -it myradius cat /etc/raddb/certs/client.key) > client.key
(docker exec -it myradius cat /etc/raddb/certs/client.crt) > client.crt
(docker exec -it myradius cat /etc/raddb/certs/ca.pem) > ca.pem

# get the ip
myradius_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' myradius)
echo $myradius_ip

# create the Radius Proxy with the previous files
docker run -dt --name myradius_proxy \
	-p 1812-1813:1812-1813/udp \
	-e Y_RADSEC_PROXY_ENABLE=yes \
	-e Y_RADSEC_PROXY_IPADDR=$myradius_ip \
	-e Y_RADSEC_PROXY_CLIENT_SECRET=strongProxySecret \
	-v ~/client.key:/etc/raddb/certs/proxy_client.key:ro \
	-v ~/client.crt:/etc/raddb/certs/proxy_client.crt:ro \
	-v ~/ca.pem:/etc/raddb/certs/proxy_ca.pem:ro \
	docker.io/palw3ey/ye3radius 
```

- Test with radclient with custom attributes
```bash
# install freeradius-utils
sudo apt install freeradius-utils

# get the ip
myradius_proxy_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' myradius_proxy)
echo $myradius_proxy_ip

# test authentication
radclient -x $myradius_proxy_ip:1812 auth strongProxySecret <<EOF
User-Name = "tux"
User-Password = "strongPassword"
NAS-IP-Address = 192.168.1.2
EOF

# verify authentication
mariadb --host=$mymariadb_ip --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "SELECT username, packet_src_ip_address, authdate FROM radpostauth ORDER BY id DESC LIMIT 2;"

# test accounting
radclient -x $myradius_proxy_ip:1813 acct strongProxySecret <<EOF
User-Name = "tux"
NAS-IP-Address = 192.168.1.2
Framed-IP-Address = 192.168.1.3
Acct-Status-Type = Start
Acct-Session-Id = 123456789
EOF

# verify accounting
mariadb --host=$mymariadb_ip --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "SELECT radacctid, acctsessionid, acctstarttime, framedipaddress FROM radacct ORDER BY radacctid DESC LIMIT 2;"
```

- Test on Windows  
[Download NTRadPing](https://community.microfocus.com/cfs-file/__key/communityserver-wikis-components-files/00-00-00-01-70/ntradping.zip)

- Manage radius database via a frontend  
[ye3radius-frontend by Kilowatt-W](https://github.com/palw3ey/ye3radius-frontend)

# GNS3

To run through GNS3, download and import the appliance : [ye3radius.gns3a](https://raw.githubusercontent.com/palw3ey/ye3radius/master/ye3radius.gns3a)

## How to connect the docker container in the GNS3 topology ?
Drag and drop the device in the topology. Right click on the device and select "Edit config".  
If you want a static configuration, uncomment the lines just below `# Static config for eth0` or otherwise `# DHCP config for eth0` for a dhcp configuration. Click "Save".  
Add a link to connect the device to a switch or router. Finally, right click on the device, select "Start".  
To see the output, right click "Console".  
To type commands, right click "Auxiliary console".  

# Environment Variables

These are the env variables and their default values.  

| variables | format | default | description |
| :- |:- |:- |:- |
|Y_LANGUAGE | text | fr_FR | Language. The list is in the folder /i18n/ |
|Y_DEBUG | yes/no | no | yes, Run freeradius with debug (-X) option |
|Y_IGNORE_CONFIG | yes/no | no | yes, To not apply file changes in the /etc/raddb/ folder. A good option if you use a custom /etc/raddb folder mounted from outside |
|Y_PORT_AUTH | port number | 1812 | Authentication port |
|Y_PORT_ACCT | port number | 1813 | Accounting port |
|Y_CERT_DAYS | integer | 3650 | Certificate expiration date in days |
|Y_CERT_KEEP | yes/no | yes | yes, To avoid recreating the certificates if already exist | 
|TZ | text | Europe/Paris | time zone, IANA format | 
|Y_DATE_FORMAT | text | "%Y-%m-%dT%H:%M:%S%z" | date format (strftime), mainly used for logs | 
|Y_TEST_NAS | yes/no | no | yes, To activate the test NAS |
|Y_TEST_NAS_ADDRESS | ip address | 0.0.0.0/0 | Test NAS address |
|Y_TEST_NAS_SECRET | password | Test10203040 | Test NAS secret |
|Y_TEST_USER | yes/no | no | yes, To activate the test user |
|Y_TEST_USER_USERNAME | name | test | Test user username |
|Y_TEST_USER_PASSWORD | password | 1234 | Test user password |
|Y_DB_ENABLE | yes/no | no | yes, To enable SQL |
|Y_DB_SERVER | address | example.com | SQL server address |
|Y_DB_PORT | port number | 3306 | SQL server port |
|Y_DB_LOGIN | name | login | SQL server login |
|Y_DB_PASSWORD | password | password | SQL server password |
|Y_DB_RADIUS_DB | text | radius | SQL database to use |
|Y_DB_TLS_REQUIRED | yes/no | no | yes, To connect to the SQL server with ssl option |
|Y_DB_READ_CLIENTS | yes/no | yes | yes, To read NAS from SQL nas table |
|Y_DB_AUTHORIZE | yes/no | yes | yes, To allow auth from SQL |
|Y_DB_POSTAUTH | yes/no | yes | yes, To allow SQL postauth |
|Y_DB_ACCOUNTING | yes/no | yes | yes, To allow SQL accounting |
|Y_DB_WAIT | integer | 5 | Number of seconds to wait between each attempt to reach the SQL server when the ye3radius container starts |
|Y_RADSEC_SERVER_ENABLE | yes/no | no | yes, To activate RadSec server |
|Y_RADSEC_SERVER_PORT | port number | 2083 | RadSec server port |
|Y_RADSEC_SERVER_TYPE | text | auth+acct | Allowed request on the port |
|Y_RADSEC_SERVER_CA | path | '${cadir}/ca.pem' | Path to the ca certificate file |
|Y_RADSEC_SERVER_KEY | path | '${certdir}/server.key' | Path to the server key file |
|Y_RADSEC_SERVER_KEY_PASSWORD | password | whatever | server key file password |
|Y_RADSEC_SERVER_CERT | path | '${certdir}/server.pem' | Path to the server certificate file |
|Y_RADSEC_SERVER_CLIENT_IPADDR | ip address | 0.0.0.0/0 | Allowed client address |
|Y_RADSEC_SERVER_REQUIRE_CERT | yes/no | no | yes, To require a client certificate |
|Y_RADSEC_PROXY_ENABLE | yes/no | no | yes, To activate Radius Proxy |
|Y_RADSEC_PROXY_CLIENT_IPADDR | ip address | 0.0.0.0/0 | Allowed client address |
|Y_RADSEC_PROXY_CLIENT_SECRET | password | Test50607080 | NAS secret |
|Y_RADSEC_PROXY_IPADDR | ip address | 127.0.0.1 | RadSec server IP address |
|Y_RADSEC_PROXY_PORT | port number | 2083 | RadSec server port |
|Y_RADSEC_PROXY_TYPE | text | auth+acct | Allowed request on the port |
|Y_RADSEC_PROXY_CA | path | '${cadir}/proxy_ca.pem' | Path to the ca certificate file |
|Y_RADSEC_PROXY_KEY | path | '${certdir}/proxy_client.key' | Path to the client key file |
|Y_RADSEC_PROXY_KEY_PASSWORD | password | whatever | client key file password |
|Y_RADSEC_PROXY_CERT | path | '${certdir}/proxy_client.crt' | Path to the client certificate file |

# Compatibility

The docker image was compiled to work on these CPU architectures :

- linux/386
- linux/amd64
- linux/arm/v6
- linux/arm/v7
- linux/arm64
- linux/ppc64le
- linux/s390x

Work on most computers including Raspberry Pi

# Build

To customize and create your own images.

```bash
git clone https://github.com/palw3ey/ye3radius.git
cd ye3radius
# Make all your modifications, then :
docker build --no-cache --network=host -t ye3radius .
docker run -dt --name my_customized_radius ye3radius
```

# Documentation

[radiusd man page](https://freeradius.org/radiusd/man/)

# Version

| name | version |
| :- |:- |
|ye3radius | 2.0.1 |
|radiusd | 3.0.27 |
|alpine | 3.21.2 |

# Changelog

## [2.0.1] - 2025-02-02
### Fixed
- add acct_pool in radsec_proxy site
## [2.0.0] - 2025-02-02
### Added
- Ease of configuration for RadSec and Radius Proxy 
- new package : tini tzdata ca-certificates curl
- include new source file in the repo : queries.conf and sqlcounter
- ability to change timezone and date format via environment variables
### Changed 
- use tini for entrypoint
- rename bypass_docker_env.sh.dis to bypass_container_env.sh 
## [1.0.0] - 2023-12-01
### Added
- première : first release

# ToDo

Feel free to contribute or share your ideas for new features, you can contact me here on github or by email. I speak French, you can write to me in other languages ​​I will find ways to translate.

# License

MIT  
author: palw3ey  
maintainer: palw3ey  
email: palw3ey@gmail.com  
website: https://github.com/palw3ey/ye3radius  
docker hub: https://hub.docker.com/r/palw3ey/ye3radius
