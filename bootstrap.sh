#!/usr/bin/env bash
set -eo pipefail

if [[ $MODE == 'dev' ]]; then
    echo "Provisioning in DEVELOPMENT mode - git-cloned bundles will be used"
fi

# APT
echo "Updating APT"
apt-get update > /dev/null 2>&1

# Set timezone.
echo "Setting up timezone..."
echo "Europe/Copenhagen" > /etc/timezone
/usr/sbin/dpkg-reconfigure --frontend noninteractive tzdata > /dev/null 2>&1

# Set locale
echo "Setting up locale..."
echo en_GB.UTF-8 UTF-8 > /etc/locale.gen
echo en_DK.UTF-8 UTF-8 >> /etc/locale.gen
echo da_DK.UTF-8 UTF-8 >> /etc/locale.gen
/usr/sbin/locale-gen > /dev/null 2>&1
export LANGUAGE=en_DK.UTF-8 > /dev/null 2>&1
export LC_ALL=en_DK.UTF-8 > /dev/null 2>&1
/usr/sbin/dpkg-reconfigure --frontend noninteractive locales > /dev/null 2>&1

# Add dotdeb
cat > /etc/apt/sources.list.d/dotdeb.list <<DELIM
deb http://packages.dotdeb.org wheezy all
deb-src http://packages.dotdeb.org wheezy all

deb http://packages.dotdeb.org wheezy-php56 all
deb-src http://packages.dotdeb.org wheezy-php56 all
DELIM
wget http://www.dotdeb.org/dotdeb.gpg > /dev/null 2>&1
apt-key add dotdeb.gpg  > /dev/null 2>&1
rm dotdeb.gpg
apt-get update > /dev/null 2>&1

# Mysql
echo "Configuring mysql"
debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password password vagrant' > /dev/null 2>&1
debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password_again password vagrant' > /dev/null 2>&1

apt-get install -y mysql-server > /dev/null 2>&1

# PHP5
echo "Installing php"
apt-get install -y php5-fpm php5-cli php5-xdebug php5-mysql php5-curl php5-gd git > /dev/null 2>&1
# Used by os2display bundle tests
apt-get install -y php5-sqlite > /dev/null 2>&1

sed -i '/;date.timezone =/c date.timezone = Europe/Copenhagen' /etc/php5/cli/php.ini
sed -i '/;date.timezone =/c date.timezone = Europe/Copenhagen' /etc/php5/fpm/php.ini

sed -i '/upload_max_filesize = 2M/cupload_max_filesize = 256M' /etc/php5/fpm/php.ini
sed -i '/post_max_size = 8M/cpost_max_size = 300M' /etc/php5/fpm/php.ini

sed -i '/;listen.owner = www-data/c listen.owner = vagrant' /etc/php5/fpm/pool.d/www.conf
sed -i '/;listen.group = www-data/c listen.group = vagrant' /etc/php5/fpm/pool.d/www.conf
sed -i '/;listen.mode = 0660/c listen.mode = 0660' /etc/php5/fpm/pool.d/www.conf

# Set php memory limit to 256mb
sed -i '/memory_limit = 128M/c memory_limit = 256M' /etc/php5/fpm/php.ini

# Redis
echo "Installing redis"
apt-get install -y redis-server > /dev/null 2>&1

# Memcache
echo "Installing memcache"
apt-get install -y memcached php5-memcached > /dev/null 2>&1

# APC
echo "Configuring APC"
apt-get install -y php-apc > /dev/null 2>&1

cat > /etc/php5/fpm/conf.d/apc.ini <<DELIM
apc.enabled=1
apc.shm_segments=1
apc.optimization=0
apc.shm_size=64M
apc.ttl=7200
apc.user_ttl=7200
apc.num_files_hint=1024
apc.mmap_file_mask=/tmp/apc.XXXXXX
apc.enable_cli=1
apc.cache_by_default=1
DELIM

# x-debug
echo "Configure x-debug"

cat << DELIM >> /etc/php5/fpm/conf.d/20-xdebug.ini
xdebug.remote_enable=1
xdebug.remote_handler=dbgp
xdebug.remote_host=192.168.50.1
xdebug.remote_port=9000
xdebug.remote_autostart=0
DELIM

# Nginx
echo "Installing nginx"
apt-get install -y nginx > /dev/null 2>&1
unlink /etc/nginx/sites-enabled/default

# Setup web root
ln -s /vagrant/htdocs /var/www

# Config files into nginx
cat > /etc/nginx/sites-available/admin.os2display.vm.conf <<DELIM
server {
  listen 80;

  server_name admin.os2display.vm;
  root /vagrant/htdocs/admin/web;

  rewrite ^ https://\$server_name\$request_uri? permanent;

  access_log /var/log/nginx/admin_access.log;
  error_log /var/log/nginx/admin_error.log;
}


# HTTPS server
#
server {
  listen 443;

  server_name admin.os2display.vm;
  root /vagrant/htdocs/admin/web;

  client_max_body_size 300m;

  access_log /var/log/nginx/admin_access.log;
  error_log /var/log/nginx/admin_error.log;

  location / {
    # try to serve file directly, fallback to rewrite
    try_files \$uri @rewriteapp;
  }

  location @rewriteapp {
    # rewrite all to app.php
    rewrite ^(.*)\$ /app_dev.php/\$1 last;
  }

  location ~ ^/(app|app_dev|config)\.php(/|\$) {
    fastcgi_pass unix:/var/run/php5-fpm.sock;
    fastcgi_split_path_info ^(.+\.php)(/.*)\$;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param HTTPS off;
  }

  # deny access to .htaccess files, if Apache's document root
  # concurs with nginx's one
  location ~ /\.ht {
    deny all;
  }

  location /bundles/ {
    add_header 'Access-Control-Allow-Origin' "*";
  }

  location /proxy/ {
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;

    proxy_buffering off;

    proxy_pass http://nodejs_search/;
    proxy_redirect off;
  }

  location /socket.io/ {
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_pass http://nodejs_search;
  }

  ssl on;
  ssl_certificate /etc/ssl/nginx/server.cert;
  ssl_certificate_key /etc/ssl/nginx/server.key;

  ssl_session_timeout 5m;

  # https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
  ssl_prefer_server_ciphers On;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
}
DELIM

cat > /etc/nginx/sites-available/screen.os2display.vm.conf <<DELIM
server {
  listen 80;

  server_name screen.os2display.vm;
  root /vagrant/htdocs/screen;

  rewrite ^ https://\$server_name\$request_uri? permanent;

  access_log /var/log/nginx/screen_access.log;
  error_log /var/log/nginx/screen_error.log;
}


# HTTPS server
#
server {
  listen 443;

  server_name screen.os2display.vm;
  root /vagrant/htdocs/screen;

  client_max_body_size 300m;

  access_log /var/log/nginx/screen_access.log;
  error_log /var/log/nginx/screen_error.log;

  location / {
    try_files \$uri \$uri/ /index.html;
  }

  location /proxy/ {
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;

    proxy_buffering off;

    proxy_pass http://nodejs_middleware/;
    proxy_redirect off;
  }

  location /socket.io/ {
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_pass http://nodejs_middleware;
  }

  ssl on;
  ssl_certificate /etc/ssl/nginx/server.cert;
  ssl_certificate_key /etc/ssl/nginx/server.key;

  ssl_session_timeout 5m;

  # https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
  ssl_prefer_server_ciphers On;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
}
DELIM

cat > /etc/nginx/sites-available/search.os2display.vm.conf <<DELIM
upstream nodejs_search {
  server 127.0.0.1:3010;
}

server {
  listen 80;

  server_name search.os2display.vm;
  rewrite ^ https://\$server_name\$request_uri? permanent;


  access_log /var/log/nginx/search_access.log;
  error_log /var/log/nginx/search_error.log;
}

# HTTPS server
#
server {
  listen 443;

  server_name search.os2display.vm;

  access_log /var/log/nginx/search_access.log;
  error_log /var/log/nginx/search_error.log;

  location / {
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;

    proxy_buffering off;

    proxy_pass http://nodejs_search/;
    proxy_redirect off;
  }

  location /socket.io/ {
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_pass http://nodejs_search;
  }

  ssl on;
  ssl_certificate /etc/ssl/nginx/server.cert;
  ssl_certificate_key /etc/ssl/nginx/server.key;

  ssl_session_timeout 5m;

  # https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
  ssl_prefer_server_ciphers On;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
}
DELIM

cat > /etc/nginx/sites-available/middleware.os2display.vm.conf <<DELIM
upstream nodejs_middleware {
  server 127.0.0.1:3020;
}

server {
  listen 80;

  server_name middleware.os2display.vm;
  rewrite ^ https://\$server_name\$request_uri? permanent;


  access_log /var/log/nginx/search_access.log;
  error_log /var/log/nginx/search_error.log;
}

# HTTPS server
#
server {
  listen 443;

  server_name middleware.os2display.vm;

  access_log /var/log/nginx/search_access.log;
  error_log /var/log/nginx/search_error.log;

  location / {
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;

    proxy_buffering off;

    proxy_pass http://nodejs_middleware/;
    proxy_redirect off;
  }

  location /socket.io/ {
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_pass http://nodejs_middleware;
  }

  ssl on;
  ssl_certificate /etc/ssl/nginx/server.cert;
  ssl_certificate_key /etc/ssl/nginx/server.key;

  ssl_session_timeout 5m;

  # https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
  ssl_prefer_server_ciphers On;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
}
DELIM

# Symlink
ln -s /etc/nginx/sites-available/search.os2display.vm.conf /etc/nginx/sites-enabled/search.os2display.vm.conf
ln -s /etc/nginx/sites-available/middleware.os2display.vm.conf /etc/nginx/sites-enabled/middleware.os2display.vm.conf
ln -s /etc/nginx/sites-available/admin.os2display.vm.conf /etc/nginx/sites-enabled/admin.os2display.vm.conf
ln -s /etc/nginx/sites-available/screen.os2display.vm.conf /etc/nginx/sites-enabled/screen.os2display.vm.conf

# SSL
mkdir /etc/ssl/nginx
openssl req -x509 -sha256 -nodes -days 1460 -newkey rsa:2048 -keyout /etc/ssl/nginx/server.key -out /etc/ssl/nginx/server.cert -subj "/C=DK/L=Aarhus/O=OS2Display/CN=admin.os2display.vm/emailAddress=itk-dev@example.com"

# Config file for middleware
cat > /vagrant/htdocs/middleware/config.json <<DELIM
{
  "port": 3020,
  "secret": "MySuperSecret",
  "logs": {
    "all": "logs/messages.log",
    "info": "logs/info.log",
    "error": "logs/error.log",
    "debug": "logs/debug.log",
    "exception": "logs/exceptions.log",
    "socket": "logs/socket.log"
  },
  "admin": {
    "username": "admin",
    "password": "admin"
  },
  "cache": {
    "port": "6379",
    "host": "localhost",
    "auth": null,
    "db": 0
  },
  "apikeys": "apikeys.json"
}
DELIM

# Config file for apikeys
cat > /vagrant/htdocs/middleware/apikeys.json <<DELIM
{
  "059d9d9c50e0c45b529407b183b6a02f": {
    "name": "IK3",
    "backend": "https://admin.os2display.vm",
    "expire": 300
  }
}
DELIM

# Config file for screen
cat > /vagrant/htdocs/screen/app/config.js <<DELIM
window.config = {
  "resource": {
    "server": "//screen.os2display.vm/",
    "uri": 'proxy'
  },
  "ws": {
    "server": "https://screen.os2display.vm/"
  },
  "apikey": "059d9d9c50e0c45b529407b183b6a02f",
  "cookie": {
    "secure": false
  },
  "debug": true,
  "version": "dev",
  "itkLog": {
    "version": "1",
    "errorCallback": null,
    "logToConsole": true,
    "logLevel": "all"
  }
};
DELIM

# NodeJS
echo "Installing nodejs"
wget https://deb.nodesource.com/setup_4.x -O /tmp/node_install.sh
chmod 700 /tmp/node_install.sh
/tmp/node_install.sh
apt-get update > /dev/null 2>&1
apt-get install -y nodejs > /dev/null 2>&1

# Search node requirements
echo "Installing search_node requirements"
su vagrant -c "cd /vagrant/htdocs/search_node && ./install.sh" > /dev/null 2>&1

# Search node requirements
echo "Installing middleware requirements"
# @TODO: remove this when logger plugin can handle a non-existing directory
mkdir /vagrant/htdocs/middleware/logs
su vagrant -c "cd /vagrant/htdocs/middleware && ./install.sh" > /dev/null 2>&1

# Search node config
cd /vagrant/htdocs/search_node/
cp example.config.json config.json

cat > /vagrant/htdocs/search_node/mappings.json <<DELIM
{
  "e7df7cd2ca07f4f1ab415d457a6e1c13": {
    "name": "os2display",
    "tag": "private",
    "fields": [
      {
        "field": "title",
        "type": "string",
        "language": "da",
        "country": "DK",
        "default_analyzer": "string_index",
        "default_indexer": "analyzed",
        "sort": true,
        "indexable": true,
        "raw": false
      },
      {
        "type": "string",
        "country": "DK",
        "language": "da",
        "default_analyzer": "string_index",
        "default_indexer": "analyzed",
        "sort": true,
        "indexable": true,
        "raw": false,
        "geopoint": false,
        "field": "name"
      }
    ],
    "dates": [ "created_at", "updated_at" ]
  },
  "itkdevshare": {
    "name": "ITK Dev Share",
    "tag": "shared",
    "fields": [
      {
        "field": "title",
        "type": "string",
        "language": "da",
        "country": "DK",
        "default_analyzer": "string_index",
        "default_indexer": "analyzed",
        "sort": true,
        "indexable": true,
        "raw": false
      },
      {
        "field": "slides",
        "indexable": false,
        "type": "object",
        "raw": false
      }
    ],
    "dates": [ "created_at", "updated_at" ]
  },
  "bibshare": {
    "name": "Biblioteks Share",
    "tag": "shared",
    "fields": [
      {
        "field": "title",
        "type": "string",
        "language": "da",
        "country": "DK",
        "default_analyzer": "string_index",
        "default_indexer": "analyzed",
        "sort": true,
        "indexable": true,
        "raw": false
      },
      {
        "field": "slides",
        "indexable": false,
        "type": "object",
        "raw": false
      }
    ],
    "dates": [ "created_at", "updated_at" ]
  }
}
DELIM

# Config file for apikeys
cat > /vagrant/htdocs/search_node/apikeys.json <<DELIM
{
  "795359dd2c81fa41af67faa2f9adbd32": {
    "name": "IK3",
    "expire": 300,
    "indexes": [
      "e7df7cd2ca07f4f1ab415d457a6e1c13",
      "de831b7bf75d90f6641b4918dde0ddba"
    ],
    "access": "rw"
  },
  "88cfd4b277f3f8b6c7c15d7a84784067": {
    "name": "Share",
    "expire": 300,
    "indexes": [
      "itkdevshare",
      "bibshare"
    ],
    "access": "rw"
  }
}
DELIM

# Search Node service script
echo "Setting up search_node service"
cat > /etc/init.d/search_node <<DELIM
#!/bin/sh

NODE_APP='app.js'
APP_DIR='/vagrant/htdocs/search_node';
PID_FILE=\$APP_DIR/app.pid
LOG_FILE=\$APP_DIR/app.log
NODE_EXEC=\`which node\`

###############
# chkconfig: - 58 74
# description: node-app is the script for starting a node app on boot.
### BEGIN INIT INFO
# Provides: search_node
# Required-Start:    \$network \$remote_fs \$local_fs
# Required-Stop:     \$network \$remote_fs \$local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: start and stop node
# Description: Node process for app
### END INIT INFO

start_app (){
    if [ -f \$PID_FILE ]
    then
        PID=\`cat $PID_FILE\`
        if ps -p \$PID > /dev/null; then
            echo "\$PID_FILE exists, process is already running"
            exit 1
        else
            rm \$PID_FILE
            start_app
        fi
    else
        echo "Starting node app..."
        if [ ! -d \$APP_DIR ]
        then
            sleep 30
        fi
        cd \$APP_DIR
        \$NODE_EXEC \$APP_DIR/\$NODE_APP  1>\$LOG_FILE 2>&1 &
        echo \$! > \$PID_FILE;
    fi
}

stop_app (){
    if [ ! -f \$PID_FILE ]
    then
        echo "\$PID_FILE does not exist, process is not running"
        exit 1
    else
        echo "Stopping \$APP_DIR/\$NODE_APP ..."
        echo "Killing \`cat \$PID_FILE\`"
        kill \`cat \$PID_FILE\`;
        rm -f \$PID_FILE;
        echo "Node stopped"
    fi
}

case "\$1" in
    start)
        start_app
    ;;

    stop)
        stop_app
    ;;

    restart)
        stop_app
        start_app
    ;;

    status)
        if [ -f \$PID_FILE ]
        then
            PID=\`cat \$PID_FILE\`
            if [ -z "\`ps ef | awk '{print \$1}' | grep "^\$PID\$"\`" ]
            then
                echo "Node app stopped but pid file exists"
            else
                echo "Node app running with pid \$PID"

            fi
        else
            echo "Node app stopped"
        fi
    ;;

    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        exit 1
    ;;
esac
DELIM
chmod +x /etc/init.d/search_node

# Make middleware service
echo "Making middleware service"
cp /etc/init.d/search_node /etc/init.d/middleware
sed -i 's/search_node/middleware/g' /etc/init.d/middleware

# Update rc
update-rc.d middleware defaults > /dev/null 2>&1
update-rc.d search_node defaults > /dev/null 2>&1

# Create database
echo "Setting up database os2display"
echo "create database os2display" | mysql -uroot -pvagrant > /dev/null 2>&1

# Get composer
echo "Setting up composer"
cd /vagrant/htdocs/admin
curl -sS http://getcomposer.org/installer | php  > /dev/null 2>&1
mv /vagrant/htdocs/admin/composer.phar /usr/local/bin/composer

# Config file for admin_os2display
cat > /vagrant/htdocs/admin/app/config/parameters.yml <<DELIM
parameters:
    database_driver: pdo_mysql
    database_host: 127.0.0.1
    database_port: null
    database_name: os2display
    database_user: root
    database_password: vagrant
    mailer_transport: smtp
    mailer_host: 127.0.0.1
    mailer_user: null
    mailer_password: null
    locale: en
    secret: ThisTokenIsNotSoSecretChangeIt
    debug_toolbar: true
    debug_redirects: false
    use_assetic_controller: true
    absolute_path_to_server: 'https://admin.os2display.vm'
    zencoder_api: 1234567890
    mailer_from_email: webmaster@ik3.os2display.dk
    mailer_from_name: Webmaster os2display
    templates_directory: ik-templates/

    sharing_host: https://search.os2display.vm
    sharing_path: /api
    sharing_apikey: 88cfd4b277f3f8b6c7c15d7a84784067

    search_host: https://search.os2display.vm
    search_path: /api
    search_apikey: 795359dd2c81fa41af67faa2f9adbd32
    search_index: e7df7cd2ca07f4f1ab415d457a6e1c13

    middleware_host: https://middleware.os2display.vm
    middleware_path: /api
    middleware_apikey: 059d9d9c50e0c45b529407b183b6a02f

    templates_slides_directory: templates/slides/
    templates_slides_enabled:
        - manual-calendar
        - only-image
        - only-video
        - portrait-text-top
        - text-bottom
        - text-left
        - text-right
        - text-top
        - ik-iframe
        - header-top
        - event-calendar
        - wayfinding

    templates_screens_directory: templates/screens/
    templates_screens_enabled:
        - full-screen
        - five-sections
        - full-screen-portrait

    site_title: os2display

    koba_apikey: b70a6d8511e05aa737ee68126d801558
    koba_path: http://192.168.50.21

    version: dev

    itk_log_version: 1
    itk_log_error_callback: /api/error
    itk_log_log_to_console: true
    itk_log_log_level: all
DELIM

# If we're in dev mode, clone bundles and patch composer.json prior to
# installing.

if [[ $MODE == 'dev' ]]; then
    su --login vagrant -c "/vagrant/scripts/install_bundles.sh"
fi

# Use the dev override composer if available.
echo "Composer installing admin, this will take a while..."

# We disable xdebug while composer is running to give us a bit more speed.
php5dismod -s cli xdebug
if [[ -f composer-dev.json ]]; then
    su --login vagrant -c "cd /vagrant/htdocs/admin && COMPOSER=composer-dev.json composer install"  > /dev/null 2>&1
else
    su --login vagrant -c "cd /vagrant/htdocs/admin && composer install > /dev/null" 2>&1
fi
php5enmod -s cli xdebug

app/console doctrine:migrations:migrate --no-interaction > /dev/null 2>&1

# Setup super-user
echo "Setting up super-user: admin/admin"
app/console fos:user:create --super-admin admin test@etek.dk admin > /dev/null 2>&1

# Fix /etc/hosts
echo "Add *.os2display.vm to hosts"
echo "127.0.1.1 screen.os2display.vm" >> /etc/hosts
echo "127.0.1.1 admin.os2display.vm" >> /etc/hosts
echo "127.0.1.1 search.os2display.vm" >> /etc/hosts
echo "127.0.1.1 middleware.os2display.vm" >> /etc/hosts

# Elastic search
echo "Installing elasticsearch"
apt-get install openjdk-7-jre -y > /dev/null 2>&1
cd /root
wget https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.1.deb > /dev/null 2>&1
dpkg -i elasticsearch-1.7.1.deb > /dev/null 2>&1
rm elasticsearch-1.7.1.deb
update-rc.d elasticsearch defaults 95 10 > /dev/null 2>&1

# Elasticsearch plugins
/usr/share/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-analysis-icu/2.5.0 > /dev/null 2>&1
/usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head > /dev/null 2>&1

# Install gulp
npm install --global gulp > /dev/null 2>&1
su --login vagrant -c "cd /vagrant/htdocs/admin && npm install" > /dev/null 2>&1
su --login vagrant -c "cd /vagrant/htdocs/screen && npm install" > /dev/null 2>&1

# Add symlink.
ln -s /vagrant/htdocs/ /home/vagrant

echo "Starting php5-fpm"
service php5-fpm restart > /dev/null 2>&1

echo "Starting nginx"
service nginx restart > /dev/null 2>&1

echo "Starting mysql"
service mysql start > /dev/null 2>&1

echo "Starting ElasticSearch"
service elasticsearch restart > /dev/null 2>&1

echo "Starting redis"
service redis-server restart > /dev/null 2>&1

echo "Starting search_node"
service search_node start > /dev/null 2>&1

echo "Starting middleware"
service middleware start > /dev/null 2>&1

echo "Adding crontab"
crontab -l > mycron
echo "*/1 * * * * /usr/bin/php /vagrant/htdocs/admin/app/console os2display:core:cron" >> mycron
crontab mycron
rm mycron

# Set up MailHog
mkdir -p /opt/mailhog/bin
chmod -Rv a+x /opt/mailhog
curl --location https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64 > /opt/mailhog/bin/MailHog
chmod a+x /opt/mailhog/bin/MailHog

cat > /etc/init.d/mailhog <<'EOF'
#! /bin/sh
# /etc/init.d/mailhog
#
# MailHog init script.
#
# @author Mikkel Ricky <rimi@aarhus.dk>

### BEGIN INIT INFO
# Provides:          mailhog
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: MailHog
# Description:       MailHog
### END INIT INFO

NAME=mailhog
DAEMON=/opt/mailhog/bin/MailHog
PIDFILE=/var/run/mailhog.pid
SCRIPTNAME=/etc/init.d/$NAME

test -f $DAEMON || exit 5

. /lib/lsb/init-functions

case $1 in
start) start-stop-daemon --start --exec $DAEMON --pidfile $PIDFILE --make-pidfile --background
       ;;
stop)  start-stop-daemon --stop --pidfile $PIDFILE
       ;;
*)     echo "Usage: $SCRIPTNAME {start|stop}"
       exit 2
       ;;
esac
EOF
chmod a+x /etc/init.d/mailhog

update-rc.d mailhog defaults
service mailhog start

cat > /etc/php5/mods-available/mailhog.ini <<'EOF'
sendmail_path = /opt/mailhog/bin/MailHog sendmail
EOF

echo "Done"
