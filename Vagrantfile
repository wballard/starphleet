# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV['BOX_NAME'] || "lxc-2"
BOX_URI = ENV['BOX_URI'] || "https://bitbucket.org/Wballard/boxes/downloads/VagrantUbuntuLXC.box"
VF_BOX_URI = ENV['VF_BOX_URI'] || "https://bitbucket.org/Wballard/boxes/downloads/VagrantUbuntuLXC-vmware_fusion.box"

Vagrant::Config.run do |config|
# Setup virtual machine box. This VM configuration code is always executed.
  config.vm.box = BOX_NAME
  config.vm.box_url = BOX_URI
  config.vm.network :hostonly, "10.1.1.2"
  system "test -n \"${STARPHLEET_PRIVATE_KEY}\" && cp \"${STARPHLEET_PRIVATE_KEY}\" \"private_keys/\""
  config.vm.provision :shell, :inline => "
  /starphleet/provision/system;
  [ -n \"#{ENV['STARPHLEET_HEADQUARTERS']}\" ] && starphleet-headquarters #{ENV['STARPHLEET_HEADQUARTERS']}"
end

Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.hostname = "ship"

  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box_url = VF_BOX_URI
    override.vm.synced_folder ".", "/starphleet"
    override.vm.synced_folder "~", "/hosthome"
    f.vmx["displayName"] = "ship"
  end

  config.vm.provider :virtualbox do |f, override|
    override.vm.box_url = BOX_URI
    override.vm.synced_folder ".", "/starphleet"
    override.vm.synced_folder "~", "/hosthome"
    f.vmx["displayName"] = "ship"
  end

end
