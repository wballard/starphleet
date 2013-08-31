# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV['BOX_NAME'] || "docker"
BOX_URI = ENV['BOX_URI'] || "http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-amd64-vagrant-disk1.box"
VF_BOX_URI = ENV['BOX_URI'] || "http://com_flyclops_bin.s3.amazonaws.com/ubuntu-13.04-vmware.box"

Vagrant.configure("2") do |config|
  config.vm.hostname = "ship"
  config.vm.network :public_network


  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box = BOX_NAME
    override.vm.box_url = VF_BOX_URI
    override.vm.synced_folder ".", "/starphleet"
    f.vmx["displayName"] = "ship"
  end

  config.vm.provider :virtualbox do |vb|
    config.vm.box = BOX_NAME
    config.vm.box_url = BOX_URI
  end

  config.vm.provision :shell, :inline => "/starphleet/provision/system"
end
