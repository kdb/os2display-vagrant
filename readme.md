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
Notice, the development setup is in heavy flux after the upgrade to version 5
of os2display that split the solution up into bundles. This has greatly complicated
the development process and require you to take some extra steps when modifying
OS2display:
You should use the scripts/setup\_htdocs.sh script to create the htdocs folder 
which clones the repositories from http://github.com/os2display. 
__NOTE__: It's important that you have clone the repositories into the htdocs 
folder before trying to boot the vagrant, as it uses configuration files located
 in the repositories during setup.

<pre>
scripts/setup_htdocs.sh
scripts/install_bundles.sh
</pre>

## Start - demo or dev
Start the setup by running either `./start-dev.sh` or `./start-demo.sh`. Dev mode
will modify create a copy of admin/composer.json in admin/composer-dev.json 
and modify it to use a local clone of the various bundles that makes up the
solution. This allows you to develop on the various bundles while the system is
 live.
 
If you on the other hand is just evaluating the system `./start-demo.sh` will 
spin up a environment that is quicker to get bootstrapped, but will not support
development.

## Post-install configuration
When the vagrant is done bootstrapping the VM you need to activate the search 
index by logging into http://search.os2display.vm and click the _indexes_ tab. 
Then click the _activate_ links foreach index.

The administrative interface can subsequently be accessed via http://admin.os2display.vm

Be aware that you will see error-messages throughout the interface until you have
created 1 instance of a 
- Slide
- Channel
- Screen

# Development
This is a work in progress, so this section will probably not cover all usecases.

## Custom bundles
See the general documentation for how to implement a bundle. When it comes to 
the development setup you have to do the folowing
* Add a .bundle file to scripts/bundled.d - see 01-core.bundle for documentation
* Clear out the development setup (delete everything in htdocs/bundles/* and remove htdocs/admin/composer-dev.json)
* Restart `vagrant destroy -f` or run `scripts/install_bundles.sh` by hand.

## Forks
You fork a bundle by
* creating a fork of a `os2display/*` bundle and naming it `<your-org>/os2display-<bundlename>`
* Add update the 01-core.bundle in scripts/bundle.d/ with your override organization, 
and consider also changing the tagged version to a branch. E.g. change
```
core-bundle@1.0.11
```
to
```
core-bundle@kdb-master@kdb
```
* Clear out the development setup (delete everything in htdocs/bundles/* and remove htdocs/admin/composer-dev.json)
* Restart `vagrant destroy -f` or run `scripts/install_bundles.sh` by hand.


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
