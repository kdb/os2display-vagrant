# Introduction
This vagrant provides the setup for a local version of the os2display server setup.

 * It installs nginx, php, mysql, symfony, nodejs, redis, etc.
 * It installs a database "os2display" for the symfony backend.
 * Afterwards it starts up the search and middleware nodejs apps.

# Vagrant setup
To enable one vagrant to have more than one alias (domain) you need to install the plugin below.

<pre>
vagrant plugin install vagrant-hostsupdater
</pre>

# Installation.
You should use the scripts/setup\_htdocs.sh script to create the htdocs folder which clones the repositories from http://github.com/os2display. _
_NOTE__: It's important that you have clone the repositories into the htdocs folder before trying to boot the vagrant, as it uses configuration files located in the repositories during setup.

<pre>
scripts/setup_htdocs.sh
scripts/install_bundles.sh
</pre>

## Start - stable mode
The vagrant setup will pr default start up in "stable" mode where the bundles 
that makes up OS2Display are installed in a stable un-modifiable form. This mode
is ideal for trying out and demoing OS2Display

<pre>
vagrant up
</pre>

## Start - development mode

By specifying `MODE=dev` when starting up vagrant all custom bundles will be 
installed via git to better support development. 
<pre>
MODE=dev vagrant up
</pre>


## Post-install configuration
When the vagrant is done bootstrapping the VM you need to activate the search index by logging into http://search.os2display.vm and click the _indexes_ tab. Then click the _activate_ links foreach index.

The administrative interface can subsequently be accessed via http://admin.os2display.vm

Be aware that you will see error-messages throughout the interface until you have
created 1 instance of a 
- Slide
- Channel
- Screen

# Troubleshoot

## How to start / restart middleware and search
If you restart your vagrant the search node and middleware might not start automatically or if the code is updated you need to restart them,
<pre>
sudo service search_node start/stop
sudo service middleware start/stop
</pre>

## MySQL access
If you need to access the database from outside the VM with e.g. _Sequel Pro_ or any other SQL client that can connect via SSH the following can be used.
<pre>
Name: os2display
MySQL Host: 127.0.0.1
Username: root
Password: vagrant
SSH Host: admin.os2display.vm
SSH User: vagrant
SSH Key: ~/.vagrant.d/insecure_private_key
</pre>

## Logs
 * The middleware and search node have logs in their root folders _/vagrant/htdocs/search_node_ and _/vagrant/htdocs/middleware_
 * Nginx have logs in _/var/log/nginx_
