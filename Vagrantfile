# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV['BOX_NAME'] || "lxc-2"
BOX_URI = ENV['BOX_URI'] || "https://bitbucket.org/Wballard/boxes/downloads/VagrantUbuntuLXC.box"
VF_BOX_URI = ENV['VF_BOX_URI'] || "https://bitbucket.org/Wballard/boxes/downloads/VagrantUbuntuLXC-vmware_fusion.box"

Vagrant::Config.run do |config|
# Setup virtual machine box. This VM configuration code is always executed.
  config.vm.box = BOX_NAME
  config.vm.box_url = BOX_URI
  system "test -d private_keys || mkdir private_keys"
  system "test -n \"${STARPHLEET_PRIVATE_KEY}\" && cp \"${STARPHLEET_PRIVATE_KEY}\" \"private_keys/\""
  system "test -d public_keys || mkdir public_keys"
  system "test -n \"${STARPHLEET_PUBLIC_KEY}\" && cp \"${STARPHLEET_PUBLIC_KEY}\" \"public_keys/\""
  system "test -n \"${STARPHLEET_HEADQUARTERS}\" && echo \"${STARPHLEET_HEADQUARTERS}\" > headquarters"
  config.vm.provision :shell, :inline => "
  /starphleet/scripts/starphleet-install;
  [ -n \"#{ENV['STARPHLEET_HEADQUARTERS']}\" ] && starphleet-headquarters #{ENV['STARPHLEET_HEADQUARTERS']}"
end

Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.hostname = "ship"
  config.vm.network "private_network", ip: "192.168.50.4"

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
