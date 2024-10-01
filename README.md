# ye3radius

A container AAA Radius server based on Freeradius and Alpine for a MySQL DB. Below 20 Mb. GNS3 ready.

The /etc/raddb folder is persistent.

# Simple usage

```bash
docker run -dt --name myradius -e Y_TEST_NAS=yes -e Y_TEST_USER=yes palw3ey/ye3radius
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
wget https://github.com/palw3ey/ye3radius/raw/main/schema.sql
mariadb --host=example.com --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius < schema.sql
mariadb --host=example.com --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "SHOW TABLES;"
```

4. Create a NAS client  
The nas_address, below, is the IP address of the host that is requesting authentication. Use 0.0.0.0/0 to allow any IP address.
```bash
nas_address="10.10.10.10"
nas_secret="strongSecret"
mariadb --host=example.com --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "INSERT INTO  nas (nasname,shortname,type,ports,secret,server,community,description) VALUES ('"$nas_address"', 'nas access sql', 'other',NULL ,'"$nas_secret"',NULL ,NULL ,'RADIUS Client');"
```

5. Create a user
```bash
employee_username="tux"
employee_password="strongPassword"
mariadb --host=example.com --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius -e "INSERT INTO radcheck (username, attribute, op, value) VALUES ('"$employee_username"', 'Cleartext-Password', ':=', '"$employee_password"');"
```

6. Include AVPair Reply  (optional)  
To include Cisco-AVPair for a user
```bash
mariadb --host=example.com --port=3306 --user=radiusDBuser --password=radiusDBpassword --database=radius
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
docker inspect --format='{{.NetworkSettings.IPAddress}}' myradius

# On a ubuntu host :
apt install freeradius-utils
radtest $employee_username $employee_password $container_ip:1812 0 $nas_secret -x
```


# Test

on the host
```bash
docker exec -it myradius sh --login -c "radtest test 1234 localhost:1812 0 testing123 -x"
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
docker exec -it myradius sh --login -c "tail -f /var/log/radius/radius.log"
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

# GNS3

To run through GNS3, download and import the appliance : [ye3radius.gns3a](https://raw.githubusercontent.com/palw3ey/ye3radius/master/ye3radius.gns3a)

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
|ye3radius | 1.0.0 |
|radiusd | 3.0.26 |
|alpine | 3.20.3 |

# ToDo

- ~~need to document env variables~~ (2023-12-12)
- add more translation files in i18n folder. Contribute ! Send me your translations by mail ;)

Don't hesitate to send me your contributions, issues, improvements on github or by mail.

# License

MIT  
author: palw3ey  
maintainer: palw3ey  
email: palw3ey@gmail.com  
website: https://github.com/palw3ey/ye3radius  
docker hub: https://hub.docker.com/r/palw3ey/ye3radius
