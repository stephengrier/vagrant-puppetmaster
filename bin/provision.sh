#!/bin/bash
# Make verbose and exit on error.
set -xe

# Install the puppetlabs YUM repo file.
rm -f /etc/yum.repos.d/puppetlabs*;
rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm;
yum update -y puppet

# Install the puppetlabs/puppetdb module.
puppet module --modulepath /vagrant/puppet/modules install puppetlabs/puppetdb
# and the zack-r10k module, which we use to configure r10k.
puppet module --modulepath /vagrant/puppet/modules install zack-r10k

exit 0;

