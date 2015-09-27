# The default manifest. Used to bootstrap the puppet master nodes.

$basedir = '/etc/puppet'

# Install puppet-server + other pre-req packages.
package {['puppet-server',
          'puppet',
          'httpd',
          'mod_ssl',
          'ruby-devel',
          'rubygems',
         ] : 
  ensure => latest,
}

# Some packages required to build ruby gems.
# package {}

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

