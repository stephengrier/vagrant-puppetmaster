# The default manifest. Used to bootstrap the puppet master nodes.

$basedir = '/etc/puppet'
$rack_app_basedir = '/usr/share/puppet/rack/puppetmasterd'

# Install puppet-server + other pre-req packages.
package {['puppet-server',
          'puppet',
          'httpd',
          'httpd-devel',
          'mod_ssl',
          'ruby-devel',
          'rubygems',
          'gcc',
          'libcurl-devel',
         ] : 
  ensure => latest,
}

# Install the following ruby gems.
package {['rack', 'passenger'] :
  ensure => installed,
  provider => 'gem',
  notify => Exec['passenger-install-apache2-module'],
}
exec {'passenger-install-apache2-module':
  command => '/usr/bin/passenger-install-apache2-module -a',
  timeout => 600,
  refreshonly => true,
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
}

file {'/etc/puppet/puppet.conf':
  ensure => file,
  content => template('/vagrant/puppet/templates/puppet.conf.erb'),
}

# Manifest dirs.
file {["${basedir}/environments",
       "${basedir}/environments/production",
       "${basedir}/environments/production/manifests",
       "${basedir}/environments/production/modules",
       "${basedir}/environments/testing",
       "${basedir}/environments/testing/manifests",
       "${basedir}/environments/testing/modules",
       "${basedir}/environments/dev",
       "${basedir}/environments/dev/manifests",
       "${basedir}/environments/dev/modules",
     ] :
  ensure => directory,
  owner => 'puppet',
  group => 'puppet',
  mode  => '0755',
}

# The WEBrick puppetmaster process should be stopped.
service {'puppetmaster':
  ensure => stopped,
  enable => false,
}
# Run apache + the rack application.
service { 'httpd':
  ensure => running,
  enable => true,
  require => File['/etc/httpd/conf.d/puppetmaster.conf'],
}

