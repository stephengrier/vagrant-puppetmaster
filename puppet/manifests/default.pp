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
      'remote'  => hiera('r10k_remote'),
      'basedir' => "${::settings::confdir}/environments",
      'prefix'  => false,
    }
  },
  notify => Exec['r10k-deploy-environments'],
}
exec {'r10k-deploy-environments':
  command => '/usr/bin/r10k deploy environment -pv',
  refreshonly => true,
}

