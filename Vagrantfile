# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV['BOX_NAME'] || "lxc"
VF_BOX_URI = ENV['BOX_URI'] || "https://bitbucket.org/Wballard/boxes/src/876e5ac82d7ebd0d761fc148b887fd1051d99b29/VagrantUbuntuLXC.box?at=master"

Vagrant.configure("2") do |config|
  config.vm.hostname = "ship"
  config.vm.network :private_network, ip: "192.168.33.10"

  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box = BOX_NAME
    override.vm.box_url = VF_BOX_URI
    override.vm.synced_folder ".", "/starphleet"
    f.vmx["displayName"] = "ship"
  end

  #THERE IS NO VirtualBox support at the moment

  config.vm.provision :shell, :inline => "/starphleet/provision/system"
end
