# -*- mode: ruby -*-
# vi: set ft=ruby :

# How many puppet master should we provision? Defaults to 1.
$num_masters = (ENV['NUM_MASTERS'] || 1).to_i
# How many client nodes should we provision? Defaults to 1.
$num_nodes = (ENV['NUM_NODES'] || 1).to_i

Vagrant.configure("2") do |config|

  # Puppet masters.
  # Possibly more than one for a load balanced setup.
  $num_masters.times do |i|
    config.vm.define "puppetmaster#{i}" do |pmconfig|
      # VM name.
      pmconfig.vm.hostname = "pm-dev-#{i}.ucl-0.ucl.ac.uk"

      # The vagrant box image to base the VM on.
      pmconfig.vm.box = "nrel/CentOS-6.5-x86_64"

      # VM memory and CPU sizing.
      pmconfig.vm.provider :virtualbox do |v|
        v.memory = 2048
        v.cpus = 2
      end

      # Network config.
      pmconfig.vm.network :private_network, ip: "192.168.33.1#{i}"

      # Provision with a shell script.
      pmconfig.vm.provision :shell, :path => "bin/provision.sh"
      # Provision the VM with puppet.
      pmconfig.vm.provision :puppet do |puppet|
        puppet.manifests_path = "puppet/manifests"
        puppet.manifest_file  = "default.pp"
        puppet.module_path = "puppet/modules"
        puppet.hiera_config_path = "puppet/hiera/hiera.yaml"
        puppet.options        = "--verbose --templatedir /vagrant/puppet/templates"
      end 

    end
  end

  # One or more client nodes.
  $num_nodes.times do |n|
    config.vm.define "clientnode#{n}" do |nconfig|
      nconfig.vm.hostname = "clientnode#{n}.example.com"

      # The vagrant box image to base the VM on.
      nconfig.vm.box = "nrel/CentOS-6.5-x86_64"

      # VM memory and CPU sizing.
      nconfig.vm.provider :virtualbox do |v|
        v.memory = 2048
        v.cpus = 2
      end

      # Provision the VM with puppet.
      nconfig.vm.provision :puppet do |puppet|
        puppet.manifests_path = "puppet/manifests"
        puppet.manifest_file  = "clientnode.pp"
      end

      # Network config.
      nconfig.vm.network :private_network, ip: "192.168.33.2#{n}"
    end
  end
end

