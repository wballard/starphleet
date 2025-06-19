# -*- mode: ruby -*-
# vi: set ft=ruby tabstop=2 expandtab shiftwidth=2 softtabstop=2 :

require 'fileutils'

VAGRANT_MEMSIZE = ENV['STARPHLEET_VAGRANT_MEMSIZE'] || '8192'
SHIP_NAME = ENV['STARPHLEET_SHIP_NAME'] || 'ship.local'
SHIP_HOSTNAME = SHIP_NAME.split('.')[0]

$base_provision_script = <<SCRIPT
cd /
sudo rsync -rav --exclude=".vagrant" /vagrant/ /starphleet/
sudo sudo cp /starphleet/scripts/starphleet-launcher /usr/bin
sudo /starphleet/scripts/starphleet-install
echo "answer AUTO_KMODS_ENABLED yes" | sudo tee -a /etc/vmware-tools/locations
sudo /starphleet/vmware_hgfs_fix.sh
sudo apt-get install -y nfs-kernel-server
# Install private keys
sudo mkdir -p /var/starphleet/private_keys
sudo mv /tmp/id_rsa /var/starphleet/private_keys
sudo chmod 600 /var/starphleet/private_keys/*
sudo chown root:root /var/starphleet/private_keys/*
# Create mounts we will expose
sudo mkdir -p /var/starphleet/headquarters
sudo mkdir -p /var/lib/lxc/data
echo "/var/starphleet/headquarters *(rw,sync,all_squash,no_subtree_check,anonuid=0,anongid=0)" > /tmp/exports
echo "/var/lib/lxc/data *(rw,sync,all_squash,no_subtree_check,anonuid=0,anongid=0)" >> /tmp/exports
sudo mv /tmp/exports /etc
sudo /etc/init.d/nfs-kernel-server restart
[ -n "#{ENV['STARPHLEET_HEADQUARTERS']}" ] \
  && [ -f /usr/bin/starphleet-headquarters ] \
  && /usr/bin/starphleet-headquarters #{ENV['STARPHLEET_HEADQUARTERS']} \
  || true;
SCRIPT

Vagrant::Config.run do |config|
  config.vm.provision "file", source: "#{ENV['STARPHLEET_PRIVATE_KEY']}", destination: "/tmp/id_rsa"
  config.vm.provision :shell, :inline => $base_provision_script
end

Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|

  unless Vagrant.has_plugin?("vagrant-triggers")
    raise 'vagrant-triggers plugin needs to be installed: vagrant plugin install vagrant-triggers'
  end

  unless Vagrant.has_plugin?("vagrant-hostmanager")
    raise 'vagrant-hostmanager plugin needs to be installed: vagrant plugin install vagrant-hostmanager'
  end

  config.trigger.before :up, :stdout => true, :force => true do
    if File.file?('./.provisioned')
      next
    end
    if not (ENV['STARPHLEET_HEADQUARTERS'] or ENV['STARPHLEET_PRIVATE_KEY'])
      raise 'Please export STARPHLEET_HEADQUARTERS, STARPHLEET_PUBLIC_KEY, STARPHLEET_PRIVATE_KEY before continuing'
    end
  end

  config.trigger.before :halt, :stdout => true, :force => true do
    system('
    sudo umount "${HOME}/starphleet_dev"
    sudo umount "${HOME}/starphleet_data"
    ')
  end

  config.trigger.before :destroy, :stdout => true, :force => true do
    system('
    [ -f ".provisioned" ] && rm ".provisioned"
    ')
  end

  config.trigger.after :up, :stdout => true, :force => true do
    system('
    mkdir -p "${HOME}/starphleet_dev"
    mkdir -p "${HOME}/starphleet_data"
    sudo mount -o resvport,soft,intr ' + SHIP_NAME + ':/var/starphleet/headquarters "${HOME}/starphleet_dev"
    sudo mount -o resvport,soft,intr ' + SHIP_NAME + ':/var/lib/lxc/data "${HOME}/starphleet_data"
    [ -f ./scripts/starphleet-devmode-update-local-ip ] && ./scripts/starphleet-devmode-update-local-ip
    touch .provisioned
    ')
  end

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.aliases = [ SHIP_NAME, 'ship.local', SHIP_HOSTNAME ]

  config.vm.hostname = SHIP_HOSTNAME

  # ssh agent forwarding, so that SSH keys can be used without passphrase if previously decrypted on host machine
  config.ssh.forward_agent = true

  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'trusty-vmware'
    override.vm.box_url = "https://s3.amazonaws.com/glg_starphleet/trusty-14.04-amd64-vmwarefusion.box"
    f.vmx["displayName"] = SHIP_HOSTNAME
    f.vmx["memsize"] = VAGRANT_MEMSIZE
  end

  config.vm.provider :virtualbox do |f, override|
    #Be warned, virtualbox is know to be a little unstable for this.
    #Fix -> buy VMWare
    override.vm.box = ENV['BOX_NAME'] || 'trusty-virtualbox'
    override.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
    f.customize ["modifyvm", :id, "--memory", VAGRANT_MEMSIZE]
    config.vm.network "private_network", :type => 'dhcp', :adapter => 2
    config.hostmanager.ip_resolver = proc do |machine|
      result = ""
      machine.communicate.execute("ifconfig eth1") do |type, data|
        result << data if type == :stdout
      end
      (ip = /^\s*inet .*?(\d+\.\d+\.\d+\.\d+)\s+/.match(result)) && ip[1]
    end
  end

  config.vm.provider :parallels do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'parallels/ubuntu-14.04'
    f.name = SHIP_HOSTNAME
    f.customize ["set", :id, "--memsize", VAGRANT_MEMSIZE]
  end
end
