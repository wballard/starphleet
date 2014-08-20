# -*- mode: ruby -*-
# vi: set ft=ruby tabstop=2 expandtab shiftwidth=2 softtabstop=2 :

VAGRANT_MEMSIZE = ENV['STARPHLEET_VAGRANT_MEMSIZE'] || '8192'
SHIP_NAME = 'ship'

Vagrant::Config.run do |config|
# Setup virtual machine box. This VM configuration code is always executed.
  system "test -d private_keys || mkdir private_keys"
  system "test -n \"${STARPHLEET_PRIVATE_KEY}\" && cp \"${STARPHLEET_PRIVATE_KEY}\" \"private_keys/\""
  system "test -d public_keys || mkdir public_keys"
  system "test -n \"${STARPHLEET_PUBLIC_KEY}\" && cp \"${STARPHLEET_PUBLIC_KEY}\" \"public_keys/\""
  system "test -n \"${STARPHLEET_HEADQUARTERS}\" && echo \"${STARPHLEET_HEADQUARTERS}\" > headquarters"
  config.vm.provision :shell, :inline => "
  source /starphleet/overlay/etc/starphleet;
  /starphleet/scripts/starphleet-install;
  [ -n \"#{ENV['STARPHLEET_HEADQUARTERS']}\" ] && starphleet-headquarters #{ENV['STARPHLEET_HEADQUARTERS']}"
end

Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.hostname = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
  config.vm.synced_folder ".", "/starphleet"
  config.vm.synced_folder "~", "/hosthome"
  # This fixes an issue on OSX with parallels, when vagrant.pkg is still mounted
  config.vm.synced_folder "./", "/vagrant", id: "some_id"

  config.vm.provider :vmware_fusion do |f, override|
    override.vm.network "public_network"
    override.vm.box = ENV['BOX_NAME'] || 'trusty-vmware'
    override.vm.box_url = "https://s3.amazonaws.com/glg_starphleet/trusty-14.04-amd64-vmwarefusion.box"
    f.vmx["displayName"] = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
    f.vmx["memsize"] = VAGRANT_MEMSIZE
    override.vm.provision :shell, :inline => "
      apt-get update;
      apt-get -y upgrade;"
  end

  config.vm.provider :virtualbox do |f, override|
    override.vm.network "public_network"
    override.vm.box = ENV['BOX_NAME'] || 'trusty-virtualbox'
    override.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
    f.customize ["modifyvm", :id, "--memory", VAGRANT_MEMSIZE]
  end

  config.vm.provider :parallels do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'saucy-parallels'
    override.vm.box_url = "https://s3.amazonaws.com/glg_starphleet/saucy-server-parallels-9-amd64-vagrant-1.4.3.box"
    f.name = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
    f.customize ["set", :id, "--memsize", VAGRANT_MEMSIZE]
  end
end
