# The default manifest. Used to bootstrap the puppet master nodes.

$basedir = '/etc/puppet'
$rack_app_basedir = '/usr/share/puppet/rack/puppetmasterd'
$puppet_port = '8140'

# Install puppet-server + other pre-req packages.
package {['puppet-server',
          'puppet',
          'httpd',
          'httpd-devel',
          'mod_ssl',
#          'ruby-devel',
#          'rubygems',
          'gcc',
          'libcurl-devel',
         ] : 
  ensure => latest,
}

class { 'puppetdb::globals':
  version => '2.3.7-1.el6',
}
# Configure puppetdb and its underlying database
class { 'puppetdb':
  database => 'postgres',
  listen_address => '0.0.0.0',
  open_listen_port => true,
}
# An exec that generates the CA and puppet master certificate keypairs.
# There's no nice way of doing this so we have to start and stop the
# puppet master process, which will generate the certs.
exec {'create puppet certs':
  command => '/sbin/service puppetmaster start && /sbin/service puppetmaster stop',
  creates => "/var/lib/puppet/ssl/public_keys/${fqdn}.pem",
  require => Package['puppet-server'],
}
exec {'puppetdb ssl-setup':
  command => '/usr/sbin/puppetdb ssl-setup',
  creates => '/etc/puppetdb/ssl/public.pem',
  require => Exec['create puppet certs'],
  before => Service['puppetdb'],
}
# Configure the puppet master to use puppetdb
class { 'puppetdb::master::config':
  puppetdb_port => '8081',
  puppet_service_name => 'httpd',
  strict_validation => false,
}

# Install the following ruby gems.
package {['rack', 'passenger'] :
  ensure => installed,
  provider => 'gem',
  notify => [Exec['passenger-install-apache2-snippet'],
             Exec['passenger-install-apache2-module']],
}
exec {'passenger-install-apache2-snippet':
  command => '/usr/bin/passenger-install-apache2-module --snippet > /etc/httpd/conf.d/mod_passenger.conf',
  refreshonly => true,
}
exec {'passenger-install-apache2-module':
  command => '/usr/bin/passenger-install-apache2-module -a',
  timeout => 600,
  refreshonly => true,
  require => Exec['passenger-install-apache2-snippet'],
  notify => Service['httpd'],
}

# Install the rack application.
file {['/usr/share/puppet/rack',
        $rack_app_basedir,
       "${rack_app_basedir}/public",
       "${rack_app_basedir}/tmp" ] :
  ensure => directory,
  owner  => 'root',
  group  => 'root',
  mode   => '0755',
}
file { '/usr/share/puppet/rack/puppetmasterd/config.ru':
  ensure  => link,
  target  => '/usr/share/puppet/ext/rack/config.ru',
  owner   => 'puppet',
  group   => 'puppet',
  require => File[$rack_app_basedir],
}

# Apache config the the puppet master VH.
file { '/etc/httpd/conf.d/puppetmaster.conf':
  ensure  => file,
  content => template('/vagrant/puppet/templates/puppetmaster.conf.erb'),
  require => Package['httpd'],
  notify => Service['httpd'],
}

file {'/etc/puppet/puppet.conf':
  ensure => file,
  content => template('/vagrant/puppet/templates/puppet.conf.erb'),
}

$fileserver_basedir = hiera('fileserver_basedir', '/etc/puppet/files')
$fileserver_mount_point_name = hiera('fileserver_mount_point_name', 'files')
file {'/etc/puppet/fileserver.conf':
  ensure => file,
  content => template('/vagrant/puppet/templates/fileserver.conf.erb'),
}

# Environments base dir.
file {"${basedir}/environments":
  ensure => directory,
  owner => 'puppet',
  group => 'puppet',
  mode  => '0755',
}

file {
  '/etc/puppet/hiera.yaml':
    ensure => 'file',
    owner => 'root',
    group => 'root',
    source => '/vagrant/puppet/files/hiera.yaml';
  '/etc/puppet/autosign.conf':
    ensure => file,
    owner => 'root',
    group => 'root',
    source => '/vagrant/puppet/files/autosign.conf';
}

file { '/etc/puppet/hieradata':
  ensure => 'directory',
  mode => '0644',
}

# The WEBrick puppetmaster process should be stopped.
service {'puppetmaster':
  ensure => stopped,
  enable => false,
}

# Allow the pupper port through the firewall.
firewall { "${puppet_port} accept - puppet":
  port   => $puppet_port,
  proto  => 'tcp',
  action => 'accept',
}

# Configure r10k from our puppet-control Git repo.
class { 'r10k':
  sources           => {
    'control' => {
      'remote'  => hiera('r10k_control_remote'),
      'basedir' => "${::settings::confdir}/environments",
      'prefix'  => false,
    },
    'fileserver' => {
      'remote'  => hiera('r10k_fileserver_remote'),
      'basedir' => hiera('fileserver_basedir', '/etc/puppet/files'),
      'prefix'  => false,
    }
  },
  notify => Exec['r10k-deploy-environments'],
}
exec {'r10k-deploy-environments':
  command => '/usr/bin/r10k deploy environment -pv',
  refreshonly => true,
}

# Install hiera-eyaml backend.
package { 'hiera-eyaml' :
  ensure => installed,
  provider => 'gem',
}
# Create location to store eyaml keys.
file { ['/var/lib/puppet/eyaml',
        '/var/lib/puppet/eyaml/keys'] :
  ensure => directory,
  owner => 'puppet',
  group => 'puppet',
  mode  => '0755',
}
# We exec a command to create the eyaml key files. The default is to run the
# eyaml createkeys command. However, it is possible to exec some other command
# by setting the eyamlkeys_command option in puppet/hieradata/global.yaml. For
# example, this might copy the keys from a file server.
$eyamlkeys_command = hiera('eyamlkeys_command', '/usr/bin/eyaml createkeys --pkcs7-private-key=/var/lib/puppet/eyaml/keys/private_key.pkcs7.pem --pkcs7-public-key=/var/lib/puppet/eyaml/keys/public_key.pkcs7.pem && chown puppet:puppet /var/lib/puppet/eyaml/keys/*.pem')

exec {'create eyaml keys':
  command => $eyamlkeys_command,
  creates => '/var/lib/puppet/eyaml/keys/private_key.pkcs7.pem',
  require => [File['/var/lib/puppet/eyaml/keys'],
              Package['hiera-eyaml']],
  before => Service['puppetdb'],
}

# Create the config.yaml file for the root user so that "eyaml edit" etc works.
file {
  '/root/.eyaml':
    ensure => directory;
  '/root/.eyaml/config.yaml':
    ensure => file,
    content => "---
pkcs7_public_key: '/var/lib/puppet/eyaml/keys/public_key.pkcs7.pem'
pkcs7_private_key: '/var/lib/puppet/eyaml/keys/private_key.pkcs7.pem'\n",
    require => File['/root/.eyaml'];
}

