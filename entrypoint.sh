#!/bin/sh

# LABEL name="ye3radius" version="2.0.1" author="palw3ey" maintainer="palw3ey" email="palw3ey@gmail.com" website="https://github.com/palw3ey/ye3radius" license="MIT" create="20250203" premiere="20231201" 

# Entrypoint for the container

# to load other env var
if [[ -f /etc/raddb/bypass_container_env.sh ]] ; then

	# create/update symbolic link for bypass_container_env.sh
	ln -sfn /etc/raddb/bypass_container_env.sh /etc/profile.d/bypass_container_env.sh
	
	# source
	source /etc/profile.d/bypass_container_env.sh > /dev/null 2>&1		
fi

# change timezone
cp /usr/share/zoneinfo/$TZ /etc/localtime
echo $TZ > /etc/timezone

# ============ [ global variable ] ============

# date format
vg_date=$(date "+$Y_DATE_FORMAT")

# default language
vg_default_language="fr_FR"

# image name
vg_name=ye3radius

# freeradius
vg_file_base=/etc/raddb
vg_file_site=$vg_file_base/sites-available/default
vg_file_radsec_server=$vg_file_base/sites-available/radsec_server
vg_file_radsec_proxy=$vg_file_base/sites-available/radsec_proxy
vg_file_sql=$vg_file_base/mods-available/sql
vg_file_sqlcounter=$vg_file_base/mods-available/sqlcounter
vg_file_queries=$vg_file_base/mods-config/sql/main/mysql/queries.conf
vg_file_ca=$vg_file_base/certs/ca.pem 
vg_file_clients=$vg_file_base/clients.conf
vg_file_users=$vg_file_base/mods-config/files/authorize

# ============ [ function ] ============

# echo information for logs
function f_log(){

	# extra info in logs, if debug on
	vl_log=""
	if [[ $Y_DEBUG == "yes" ]]; then
		vl_log="$vg_date $(hostname) $vg_name:"
	fi

	echo -e "$vl_log $@"
}

# update env value in config file
function f_env(){
	vl_env=$1
	vl_var=$2
	vl_val=$3
	vl_file=$4
	vl_mode=$5
	if [ "$vl_mode" == "enable" ]; then
		vl_data="$vl_var"
		vl_log="$i_enable"
	elif [ "$vl_mode" == "disable" ]; then
		vl_data="#$vl_var"
		vl_log="$i_disable"
	elif [ "$vl_mode" == "comment" ]; then
		vl_data="#$vl_var = $vl_val"
		vl_log="$i_comment"
	else
		vl_data="$vl_var = $vl_val"
		vl_log="$i_set"
	fi
	sed -i "/^$vl_env/{ n; s|.*$vl_var.*|$vl_data|}" $vl_file
	f_log "$vl_log $vl_env"
}

# to do before container exit
function f_pre_exit(){
 	kill -TERM "$child" 2>/dev/null
}

# ============ [ timestamp ] ============

echo $vg_date

# ============ [ internationalisation ] ============

# load default language
source /i18n/$vg_default_language.sh

# override with choosen language
if [[ $Y_LANGUAGE != $vg_default_language ]] && [[ -f /i18n/$Y_LANGUAGE.sh ]] ; then
	source /i18n/$Y_LANGUAGE.sh
fi

f_log "i18n : $Y_LANGUAGE"

# ============ [ unnecessary config ] ============

if [[ $Y_IGNORE_CONFIG == "no" ]]; then

	f_log "$i_apply_configuration"
	
	# ============ [[ configure cert ]] ============
	
	if [[ ! -f $vg_file_ca ]] || [[ $Y_CERT_KEEP == "no" ]]; then

		f_log "$i_configure_certificates"

		sed -i "s/.*default_days.*/default_days = $Y_CERT_DAYS/" $vg_file_base/certs/ca.cnf
		sed -i "s/.*default_days.*/default_days = $Y_CERT_DAYS/" $vg_file_base/certs/inner-server.cnf
		sed -i "s/.*default_days.*/default_days = $Y_CERT_DAYS/" $vg_file_base/certs/server.cnf
		sed -i "s/.*default_days.*/default_days = $Y_CERT_DAYS/" $vg_file_base/certs/client.cnf

	fi
	
	# ============ [[ configure port ]] ============
	
	f_env "#ENV.Y_PORT_AUTH" port $Y_PORT_AUTH $vg_file_site
	f_env "#ENV.Y_PORT_ACCT" port $Y_PORT_ACCT $vg_file_site
	
	# ============ [[ configure credentials ]] ============
	
	sed -i "/#env.Y_TEST_NAS.start/,/#env.Y_TEST_NAS.end/d" $vg_file_clients
	if [[ $Y_TEST_NAS == "yes" ]]; then
		f_log "$i_create_test_nas"
		sed -i "1 i\#env.Y_TEST_NAS.start\nclient ye3radius_client {\n    ipaddr = $Y_TEST_NAS_ADDRESS\n    secret = $Y_TEST_NAS_SECRET\n    shortname = ye3radius_client\n}\n#env.Y_TEST_NAS.end" $vg_file_clients
	fi
	
	sed -i "/#env.Y_TEST_USER.start/,/#env.Y_TEST_USER.end/d" $vg_file_users
	if [[ $Y_TEST_USER == "yes" ]]; then
		f_log "$i_create_test_user"
		sed -i "1 i\#env.Y_TEST_USER.start\n$Y_TEST_USER_USERNAME    Cleartext-Password := \"$Y_TEST_USER_PASSWORD\"\n#env.Y_TEST_USER.end" $vg_file_users
	fi
	
	# ============ [[ configure sql ]] ============

	if [[ $Y_DB_ENABLE == "yes" ]]; then
	
		f_log "$i_load_sql_in_first_position"
		sed -i 's|.*$INCLUDE mods-enabled/sql.*|$INCLUDE mods-enabled/sql|' $vg_file_base/radiusd.conf

		if [[ $Y_DB_AUTHORIZE == "yes" ]]; then
			vt_mode=enable
		else
			vt_mode=disable
		fi
		f_env "#ENV.Y_DB_AUTHORIZE" -sql -sql $vg_file_site $vt_mode

		if [[ $Y_DB_ACCOUNTING == "yes" ]]; then
			vt_mode=enable
		else 
			vt_mode=disable
		fi
		f_env "#ENV.Y_DB_ACCOUNTING" -sql -sql $vg_file_site $vt_mode

		if [[ $Y_DB_POSTAUTH == "yes" ]]; then
			vt_mode=enable
		else 
			vt_mode=disable
		fi
		f_env "#ENV.Y_DB_POSTAUTH" -sql -sql $vg_file_site $vt_mode
		
		f_env "#ENV.Y_DB_READ_CLIENTS" read_clients $Y_DB_READ_CLIENTS $vg_file_sql
		f_env "#ENV.Y_DB_RADIUS_DB" radius_db $Y_DB_RADIUS_DB $vg_file_sql
		f_env "#ENV.Y_DB_SERVER" server $Y_DB_SERVER $vg_file_sql
		f_env "#ENV.Y_DB_PORT" port $Y_DB_PORT $vg_file_sql
		f_env "#ENV.Y_DB_LOGIN" login $Y_DB_LOGIN $vg_file_sql
		f_env "#ENV.Y_DB_PASSWORD" password $Y_DB_PASSWORD $vg_file_sql
		f_env "#ENV.Y_DB_TLS_REQUIRED" tls_required $Y_DB_TLS_REQUIRED $vg_file_sql

		f_log "$i_waiting_for_SQL_server"
		until nc -z -w $Y_DB_WAIT $Y_DB_SERVER $Y_DB_PORT ; do
			printf '.' > /dev/stdout
			sleep $Y_DB_WAIT
		done
		
		f_log "$i_enable sql mods"
		ln -sfn $vg_file_sql $vg_file_base/mods-enabled/sql
		ln -sfn $vg_file_sqlcounter $vg_file_base/mods-enabled/sqlcounter
		
	else
	
		f_log "$i_disable sql mods"
		rm $vg_file_base/mods-enabled/sql > /dev/null 2>&1
		rm $vg_file_base/mods-enabled/sqlcounter > /dev/null 2>&1
		
	fi
	
	
	# ============ [[ configure radsec server ]] ============
	
	
	if [[ $Y_RADSEC_SERVER_ENABLE == "yes" ]]; then
	
		f_log "$i_enable radsec_server site"
		
		f_env "#ENV.Y_RADSEC_SERVER_PORT" port $Y_RADSEC_SERVER_PORT $vg_file_radsec_server
		f_env "#ENV.Y_RADSEC_SERVER_TYPE" type $Y_RADSEC_SERVER_TYPE $vg_file_radsec_server
		f_env "#ENV.Y_RADSEC_SERVER_CA" ca_file $Y_RADSEC_SERVER_CA $vg_file_radsec_server
		f_env "#ENV.Y_RADSEC_SERVER_KEY" private_key_file $Y_RADSEC_SERVER_KEY $vg_file_radsec_server
		f_env "#ENV.Y_RADSEC_SERVER_KEY_PASSWORD" private_key_password $Y_RADSEC_SERVER_KEY_PASSWORD $vg_file_radsec_server
		f_env "#ENV.Y_RADSEC_SERVER_CERT" certificate_file $Y_RADSEC_SERVER_CERT $vg_file_radsec_server
		f_env "#ENV.Y_RADSEC_SERVER_CLIENT_IPADDR" ipaddr $Y_RADSEC_SERVER_CLIENT_IPADDR $vg_file_radsec_server
		f_env "#ENV.Y_RADSEC_SERVER_REQUIRE_CERT" require_client_cert $Y_RADSEC_SERVER_REQUIRE_CERT $vg_file_radsec_server
		
		ln -sfn $vg_file_radsec_server $vg_file_base/sites-enabled/radsec_server
	else
		f_log "$i_disable radsec_server site"
		rm $vg_file_base/sites-enabled/radsec_server > /dev/null 2>&1
	fi
	
	
	# ============ [[ configure radsec proxy ]] ============
	
	if [[ $Y_RADSEC_PROXY_ENABLE == "yes" ]]; then
	
		f_log "$i_enable radsec_proxy site"
		
		f_env "#ENV.Y_RADSEC_PROXY_IPADDR" ipaddr $Y_RADSEC_PROXY_IPADDR $vg_file_radsec_proxy
		f_env "#ENV.Y_RADSEC_PROXY_PORT" port $Y_RADSEC_PROXY_PORT $vg_file_radsec_proxy
		f_env "#ENV.Y_RADSEC_PROXY_TYPE" type $Y_RADSEC_PROXY_TYPE $vg_file_radsec_proxy
		f_env "#ENV.Y_RADSEC_PROXY_CA" ca_file $Y_RADSEC_PROXY_CA $vg_file_radsec_proxy
		f_env "#ENV.Y_RADSEC_PROXY_KEY" private_key_file $Y_RADSEC_PROXY_KEY $vg_file_radsec_proxy
		f_env "#ENV.Y_RADSEC_PROXY_KEY_PASSWORD" private_key_password $Y_RADSEC_PROXY_KEY_PASSWORD $vg_file_radsec_proxy
		f_env "#ENV.Y_RADSEC_PROXY_CERT" certificate_file $Y_RADSEC_PROXY_CERT $vg_file_radsec_proxy
		
		sed -i '/#env.Y_RADSEC_PROXY_AUTHORIZE.start/,/#env.Y_RADSEC_PROXY_AUTHORIZE.end/ { /^#env.Y_RADSEC_PROXY_AUTHORIZE.start/! { /^#env.Y_RADSEC_PROXY_AUTHORIZE.end/! s/^#//; } }' $vg_file_site
		sed -i '/#env.Y_RADSEC_PROXY_PREACCT.start/,/#env.Y_RADSEC_PROXY_PREACCT.end/ { /^#env.Y_RADSEC_PROXY_PREACCT.start/! { /^#env.Y_RADSEC_PROXY_PREACCT.end/! s/^#//; } }' $vg_file_site
		
		sed -i "/#env.Y_RADSEC_PROXY_CLIENT_IPADDR.start/,/#env.Y_RADSEC_PROXY_CLIENT_IPADDR.end/d" $vg_file_clients
		sed -i "1 i\#env.Y_RADSEC_PROXY_CLIENT_IPADDR.start\nclient ye3radius_radsec_proxy {\n    ipaddr = $Y_RADSEC_PROXY_CLIENT_IPADDR\n    secret = $Y_RADSEC_PROXY_CLIENT_SECRET\n    shortname = ye3radius_radsec_proxy\n}\n#env.Y_RADSEC_PROXY_CLIENT_IPADDR.end" $vg_file_clients
	
		ln -sfn $vg_file_radsec_proxy $vg_file_base/sites-enabled/radsec_proxy
	else
		f_log "$i_disable radsec_proxy site"
		sed -i '/#env.Y_RADSEC_PROXY_AUTHORIZE.start/,/#env.Y_RADSEC_PROXY_AUTHORIZE.end/ { /^#env.Y_RADSEC_PROXY_AUTHORIZE.start/! { /^#env.Y_RADSEC_PROXY_AUTHORIZE.end/! s/^/#/; } }' $vg_file_site
		sed -i '/#env.Y_RADSEC_PROXY_PREACCT.start/,/#env.Y_RADSEC_PROXY_PREACCT.end/ { /^#env.Y_RADSEC_PROXY_PREACCT.start/! { /^#env.Y_RADSEC_PROXY_PREACCT.end/! s/^/#/; } }' $vg_file_site
		
		sed -i "/#env.Y_RADSEC_PROXY_CLIENT_IPADDR.start/,/#env.Y_RADSEC_PROXY_CLIENT_IPADDR.end/d" $vg_file_clients
		
		rm $vg_file_base/sites-enabled/radsec_proxy > /dev/null 2>&1
	fi
	
	# ============ [[ enable sites ]] ============
	
	f_log "$i_enable default site"
	ln -sfn $vg_file_site $vg_file_base/sites-enabled/
	
	f_log "$i_enable inner-tunnel site"
	ln -sfn $vg_file_base/sites-available/inner-tunnel $vg_file_base/sites-enabled/
	
else

	f_log "$i_ignore_configuration"
	
fi

# ============ [ necessary config ] ============

if [[ ! -f $vg_file_ca ]] || [[ $Y_CERT_KEEP == "no" ]]; then

	f_log "$i_creating_certificates"
	
	cd $vg_file_base/certs/
	find . -type f -name "*.pem" -o -name "*.der" -o -name "*.csr" -o -name "*.crt" -o -name "*.key" -o -name "*.p12" -o -name "serial*" -o -name "index.txt*" ! -name "proxy_*" -exec rm -f {} +
	$vg_file_base/certs/bootstrap > /dev/null 2>&1
	chown -R root:radius $vg_file_base/certs
	chmod 640 $vg_file_base/certs/*.pem
	
	if [[ $Y_RADSEC_PROXY_ENABLE == "yes" ]]; then
		if [[ ! -f $vg_file_base/certs/proxy_client.key ]] ; then
			cp $vg_file_base/certs/client.key $vg_file_base/certs/proxy_client.key
		fi
		if [[ ! -f $vg_file_base/certs/proxy_client.crt ]] ; then
			cp $vg_file_base/certs/client.crt $vg_file_base/certs/proxy_client.crt
		fi
		if [[ ! -f $vg_file_base/certs/proxy_ca.pem ]] ; then
			cp $vg_file_base/certs/ca.pem $vg_file_base/certs/proxy_ca.pem
		fi
	fi
	
fi

# ============ [ start service ] ============

f_log "$i_start freeradius"

if [[ $Y_DEBUG == "yes" ]]; then
	f_log "$i_with_debug_option"
	radiusd -fxxl stdout -d $vg_file_base &
	child=$!
else
	radiusd -f -d $vg_file_base &
	child=$!
fi

f_log ":: $i_ready ::"

# catch SIGTERM
trap f_pre_exit SIGINT SIGQUIT SIGTERM

# keep the server running,
if [[ $Y_DEBUG == "yes" ]]; then
	# by using tail
	tail -f /dev/null
else
	# by waiting child process 
	wait "$child"
fi

# before final exit
f_pre_exit

f_log ":: $i_finished ::"
