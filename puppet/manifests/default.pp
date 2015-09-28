# The default manifest. Used to bootstrap the puppet master nodes.

$basedir = '/etc/puppet'

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

service {'puppetmaster':
  ensure => running,
  require => [File['/etc/puppet/puppet.conf'],
              
             ],
}

