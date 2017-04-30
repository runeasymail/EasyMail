# Get variables
export EASYMAIL_CONFIG="/opt/easymail/config.ini"
export SSL_CA_BUNDLE_FILE=$(cat "$EASYMAIL_CONFIG" | grep public_dovecot_key: | awk -F':' '{ print $2;}')
export SSL_PRIVATE_KEY_FILE=$(cat "$EASYMAIL_CONFIG" | grep private_dovecot_key: | awk -F':' '{ print $2;}')
export MYSQL_HOSTNAME=$(cat "$EASYMAIL_CONFIG" | grep mysql_easymail_hostname: | awk -F':' '{ print $2;}')
export ROOT_MYSQL_USERNAME=$(cat "$EASYMAIL_CONFIG" | grep mysql_root_username: | awk -F':' '{ print $2;}')
export ROOT_MYSQL_PASSWORD=$(cat "$EASYMAIL_CONFIG" | grep mysql_root_password: | awk -F':' '{ print $2;}')
export MYSQL_DATABASE=$(cat "$EASYMAIL_CONFIG" | grep mysql_easymail_database: | awk -F':' '{ print $2;}')

# Ask for input data
if [ "$HOSTNAME" == "" ]; then
	read -p "Type hostname: " HOSTNAME
fi

# Re-generate the Dovecot's self-signed certificate
openssl req -new -x509 -days 365000 -nodes -subj "/C=/ST=/L=/O=/CN=EasyMail" -out "$SSL_CA_BUNDLE_FILE" -keyout "$SSL_PRIVATE_KEY_FILE"

# Set HOSTNAME
	# Auto configurations
set_hostname /usr/share/nginx/autoconfig_and_autodiscover/autoconfig.php
set_hostname /usr/share/nginx/autoconfig_and_autodiscover/autodiscover.php
	# Roundcube
set_hostname /etc/nginx/sites-enabled/roundcube
	# Postfix
debconf-set-selections <<< "postfix postfix/mailname string $HOSTNAME"
	# MySQL 
export ADMIN_EMAIL="admin@$HOSTNAME"
mysql -h $MYSQL_HOSTNAME -u$ROOT_MYSQL_USERNAME -p$ROOT_MYSQL_PASSWORD << EOF
USE $MYSQL_DATABASE;

UPDATE \`virtual_domains\`
SET \`name\`='$HOSTNAME'
WHERE \`id\`='1';

UPDATE \`virtual_users\`
SET \`email\`='$ADMIN_EMAIL'
WHERE \`id\`='1';

EOF
	# Dovecot
mv /var/mail/vhosts/__EASYMAIL_HOSTNAME__ /var/mail/vhosts/$HOSTNAME
sed -i "s/admin@__EASYMAIL_HOSTNAME__/admin@$HOSTNAME/g" /etc/dovecot/conf.d/20-lmtp.conf
	# Reload services
service nginx restart 
service dovecot reload
service postfix reload
	# Management API
sed -i "s/__EASYMAIL_HOSTNAME__/$HOSTNAME/g" /opt/easymail/ManagementAPI/config.ini
pkill ManagementAPI && cd /opt/easymail/ManagementAPI && ./ManagementAPI &

# Add new configurations to easymail config file
sed -i "s/roundcube_url:.*/roundcube_url:https:\/\/$HOSTNAME\//" $EASYMAIL_CONFIG
sed -i "s/roundcube_username:.*/roundcube_username:$ADMIN_EMAIL/" $EASYMAIL_CONFIG
sed -i "s/api_url:.*/api_url:https:\/\/$HOSTNAME\/api/" $EASYMAIL_CONFIG
