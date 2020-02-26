# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"

  config.vm.provider "virtualbox" do |vb|
    # the default (1GB) does not suffice for building SCION
    vb.memory = "4096"
    # required on a Windows host to allow "ln -s" on /vagrant
    vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
  end
  
  config.vm.provision "shell", path: "provision.sh", privileged: false
end