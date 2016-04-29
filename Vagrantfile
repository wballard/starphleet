# -*- mode: ruby -*-
# vi: set ft=ruby tabstop=2 expandtab shiftwidth=2 softtabstop=2 :

require 'fileutils'

VAGRANT_MEMSIZE = ENV['STARPHLEET_VAGRANT_MEMSIZE'] || '8192'
SHIP_NAME = 'ship'

$base_provision_script = <<SCRIPT
sudo bash -c "$(curl -s https://raw.githubusercontent.com/wballard/starphleet/master/webinstall)"
# sudo cp /starphleet/scripts/starphleet-launcher /usr/bin;
# sudo /starphleet/scripts/starphleet-install;
sudo apt-get install -y nfs-kernel-server
echo "/var/starphleet/headquarters *(rw,sync,all_squash,no_subtree_check,anonuid=0,anongid=0)" > /tmp/exports
sudo mv /tmp/exports /etc
$([ -n "#{ENV['STARPHLEET_HEADQUARTERS']}" ] && starphleet-headquarters #{ENV['STARPHLEET_HEADQUARTERS']}) || true;
SCRIPT

system("
  if [ #{ARGV[0]} = 'up' ] && [ -f ./scripts/starphleet-devmode-update-local-ip ]; then
    ./scripts/starphleet-devmode-update-local-ip
  fi
")

Vagrant::Config.run do |config|
  config.vm.provision :shell, :inline => $base_provision_script
  system('
    SCP="scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
    SSH="ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
    ${SSH} "vagrant@ship.local" "sudo mkdir -p /var/starphleet/private_keys"
    ${SSH} "vagrant@ship.local" "sudo chmod 777 /var/starphleet/private_keys"
    ${SCP} "${STARPHLEET_PRIVATE_KEY}" "vagrant@ship.local:/var/starphleet/private_keys"
    ${SSH} "vagrant@ship.local" "sudo chmod 600 /var/starphleet/private_keys"
    ${SSH} "vagrant@ship.local" "sudo chmod 600 /var/starphleet/private_keys/*"
    ${SSH} "vagrant@ship.local" "sudo chown root:root /var/starphleet/private_keys/*"
  ')
end


Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|

  unless Vagrant.has_plugin?("vagrant-triggers")
    raise 'vagrant-triggers plugin needs to be installed: vagrant plugin install vagrant-triggers'
  end

  unless Vagrant.has_plugin?("vagrant-hostmanager")
    raise 'vagrant-hostmanager plugin needs to be installed: vagrant plugin install vagrant-hostmanager'
  end

  config.trigger.before :up, :stdout => true, :force => true do
    # If the machine is already provisioned - Don't do it again
    # if Dir.exists? 'private_keys' and Dir.exists? 'public_keys' and File.exists? 'headquarters'
    #   next
    # end

    if not (ENV['STARPHLEET_HEADQUARTERS'] or ENV['STARPHLEET_PUBLIC_KEY'] or ENV['STARPHLEET_PRIVATE_KEY'])
      raise 'Please export STARPHLEET_HEADQUARTERS, STARPHLEET_PUBLIC_KEY, STARPHLEET_PRIVATE_KEY before continuing'
    end
  end

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.aliases = [ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME, 'ship.local', 'ship.glgresearch.com']

  config.vm.hostname = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
  # config.vm.synced_folder ".", "/starphleet"
  # config.vm.synced_folder "~", "/hosthome"

  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'trusty-vmware'
    override.vm.box_url = "https://s3.amazonaws.com/glg_starphleet/trusty-14.04-amd64-vmwarefusion.box"
    f.vmx["displayName"] = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
    f.vmx["memsize"] = VAGRANT_MEMSIZE
  end

  config.vm.provider :virtualbox do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'trusty-virtualbox'
    f.customize ["modifyvm", :id, "--memory", VAGRANT_MEMSIZE]
  end

  config.vm.provider :parallels do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'parallels/ubuntu-14.04'
    f.name = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
    f.customize ["set", :id, "--memsize", VAGRANT_MEMSIZE]
    # config.vm.synced_folder "./", "/vagrant", id: "some_id"
  end
end
