# -*- mode: ruby -*-
# vi: set ft=ruby tabstop=2 expandtab shiftwidth=2 softtabstop=2 :

require 'fileutils'

VAGRANT_MEMSIZE = ENV['STARPHLEET_VAGRANT_MEMSIZE'] || '8192'
SHIP_NAME = 'ship'

$base_provision_script = <<SCRIPT
test -d /hosthome/starphleet_dev/ && rm -rf /hosthome/starphleet_dev/;
sudo cp /starphleet/scripts/starphleet-launcher /usr/bin;
#sudo /starphleet/scripts/starphleet-install;
$([ -n "#{ENV['STARPHLEET_HEADQUARTERS']}" ] && starphleet-headquarters #{ENV['STARPHLEET_HEADQUARTERS']}) || true;
SCRIPT

# This install of starphleet updates the kernel.  These patches must be run
# at the end of the starphleet-install - these settings are only applicable
# to
$fix_vmware_tools_script = <<SCRIPT
echo linux-image-3.13.0-24-generic hold | dpkg --set-selections
echo linux-image-generic hold | dpkg --set-selections
[ ! -f /tmp/patched ] && touch /tmp/patched || exit 0
/starphleet/vmware_hgfs_fix.sh;
sed -i.bak 's/answer AUTO_KMODS_ENABLED_ANSWER no/answer AUTO_KMODS_ENABLED_ANSWER yes/g' /etc/vmware-tools/locations;
sed -i.bak 's/answer AUTO_KMODS_ENABLED no/answer AUTO_KMODS_ENABLED yes/g' /etc/vmware-tools/locations;
SCRIPT

Vagrant::Config.run do |config|
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
    # If the machine is already provisioned - Don't do it again
    if Dir.exists? 'private_keys' and Dir.exists? 'public_keys' and File.exists? 'headquarters'
      next
    end

    if not (ENV['STARPHLEET_HEADQUARTERS'] or ENV['STARPHLEET_PUBLIC_KEY'] or ENV['STARPHLEET_PRIVATE_KEY'])
      raise 'Please export STARPHLEET_HEADQUARTERS, STARPHLEET_PUBLIC_KEY, STARPHLEET_PRIVATE_KEY before continuing'
    end

    FileUtils.mkdir 'private_keys' unless Dir.exists? 'private_keys'
    FileUtils.mkdir 'public_keys' unless Dir.exists? 'public_keys'

    FileUtils.cp ENV['STARPHLEET_PRIVATE_KEY'], 'private_keys'
    FileUtils.cp ENV['STARPHLEET_PUBLIC_KEY'], 'public_keys'
    File.open('headquarters', 'w') do |f|
      f.write ENV['STARPHLEET_HEADQUARTERS']
    end
  end

  config.trigger.after :destroy, :stdout => true, :force => true do
    FileUtils.rm_rf 'private_keys'
    FileUtils.rm_rf 'public_keys'
    FileUtils.rm_rf 'headquarters'
  end

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.aliases = [ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME, 'ship.local', 'ship.glgresearch.com']

  config.vm.hostname = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
  config.vm.synced_folder ".", "/starphleet"
  config.vm.synced_folder "~", "/hosthome"

  config.vm.provider :vmware_fusion do |f, override|
    # override.vm.network "public_network"
    override.vm.box = ENV['BOX_NAME'] || 'trusty-vmware'
    override.vm.box_url = "https://s3.amazonaws.com/glg_starphleet/trusty-14.04-amd64-vmwarefusion.box"
    f.vmx["displayName"] = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
    f.vmx["memsize"] = VAGRANT_MEMSIZE
    config.vm.provision :shell, :inline => $fix_vmware_tools_script
  end

  config.vm.provider :virtualbox do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'trusty-virtualbox'
    #this box_url is totally hosed
    f.customize ["modifyvm", :id, "--memory", VAGRANT_MEMSIZE]
  end

  config.vm.provider :parallels do |f, override|
    override.vm.box = ENV['BOX_NAME'] || 'parallels/ubuntu-14.04'
    f.name = ENV['STARPHLEET_SHIP_NAME'] || SHIP_NAME
    f.customize ["set", :id, "--memsize", VAGRANT_MEMSIZE]
    # This fixes an issue on OSX with parallels, when vagrant.pkg is still mounted
    config.vm.synced_folder "./", "/vagrant", id: "some_id"
  end
end
