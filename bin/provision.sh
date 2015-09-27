#!/bin/bash
# Make verbose and exit on error.
set -xe

# Install the puppetlabs YUM repo file.
rm -f /etc/yum.repos.d/puppetlabs*;
rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm;

exit 0;

