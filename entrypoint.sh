#!/bin/sh

# LABEL name="ye3radius" version="1.0.0" author="palw3ey" maintainer="palw3ey" email="palw3ey@gmail.com" website="https://github.com/palw3ey/ye3radius" license="MIT" create="20231201" update="20231201"

# Entrypoint for docker

# ============ [ global variable ] ============

vg_file_base=/etc/raddb
vg_file_site=$vg_file_base/sites-available/default
vg_file_sql=$vg_file_base/mods-available/sql
vg_file_ca=$vg_file_base/certs/ca.pem 
vg_file_clients=$vg_file_base/clients.conf
vg_file_users=$vg_file_base/mods-config/files/authorize

# ============ [ function ] ============

# echo information for docker logs
function f_log(){
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') $(hostname) ye3radius: $@"
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

# ============ [ internationalisation ] ============

if [[ -f /i18n/$Y_LANGUAGE.sh ]]; then
	f_log "i18n $Y_LANGUAGE"
	source /i18n/$Y_LANGUAGE.sh
else
	f_log "i18n fr_FR"
	source /i18n/fr_FR.sh
fi

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
		sed -i "1 i\#env.Y_TEST_NAS.start\nclient $Y_TEST_NAS_ADDRESS {\n    secret = $Y_TEST_NAS_SECRET\n    shortname = ye3radius_client\n}\n#env.Y_TEST_NAS.end" $vg_file_clients
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
		ln -sfn $vg_file_sql $vg_file_base/mods-enabled/
		ln -sfn $vg_file_base/mods-available/sqlcounter $vg_file_base/mods-enabled/
		
	else
	
		f_log "$i_disable sql mods"
		rm $vg_file_base/mods-enabled/sql > /dev/null 2>&1
		rm $vg_file_base/mods-enabled/sqlcounter > /dev/null 2>&1
		
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
	rm -f *.pem *.der *.csr *.crt *.key *.p12 serial* index.txt*
	$vg_file_base/certs/bootstrap > /dev/null 2>&1
	chown -R root:radius $vg_file_base/certs
	chmod 640 $vg_file_base/certs/*.pem
	
fi

# ============ [ start service ] ============

f_log "$i_start freeradius"

if [[ $Y_DEBUG == "yes" ]]; then
	f_log "$i_with_debug_option"
	radiusd -f -d $vg_file_base -X &
else
	radiusd -f -d $vg_file_base &
fi

f_log ":: $i_ready ::"

# keep the server running
tail -f /dev/null
