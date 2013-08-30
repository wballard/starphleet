# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV['BOX_NAME'] || "docker"
BOX_URI = ENV['BOX_URI'] || "http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-amd64-vagrant-disk1.box"
VF_BOX_URI = ENV['BOX_URI'] || "http://com_flyclops_bin.s3.amazonaws.com/ubuntu-13.04-vmware.box"
AWS_REGION = ENV['AWS_REGION'] || "us-east-1"
AWS_AMI    = ENV['AWS_AMI']    || "XXXX"
FORWARD_DOCKER_PORTS = ENV['FORWARD_DOCKER_PORTS']

Vagrant::Config.run do |config|
  # Setup virtual machine box. This VM configuration code is always executed.
  config.vm.box = BOX_NAME
  config.vm.box_url = BOX_URI
  config.vm.forward_port 4243, 4243

  pkg_cmd = "" \
    "apt-get -y install git curl;" \
    "curl http://get.docker.io/gpg | apt-key add -;" \
    "echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list;" \
    "apt-get update;" \
    "apt-get install linux-image-extra-`uname -r`;" \
    "apt-get -y install lxc-docker;" \
    "sudo docker images;" \
    "groupadd docker;" \
    "gpasswd -a vagrant docker;" \
    "chmod 0777 /var/run/docker.sock;" \
    "rm -rf /opt/starphleet;" \
    "git clone https://github.com/wballard/starphleet.git /opt/starphleet;" \
    "cd /opt/starphleet; docker build -t starphleet .;"
  config.vm.provision :shell, :inline => pkg_cmd
end


# Providers were added on Vagrant >= 1.1.0
Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.provider :aws do |aws, override|
    aws.access_key_id = ENV["AWS_ACCESS_KEY_ID"]
    aws.secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
    aws.keypair_name = ENV["AWS_KEYPAIR_NAME"]
    override.ssh.private_key_path = ENV["AWS_SSH_PRIVKEY"]
    override.ssh.username = "ubuntu"
    aws.region = AWS_REGION
    aws.ami    = AWS_AMI
    aws.instance_type = "t1.micro"
  end

  config.vm.provider :rackspace do |rs|
    config.ssh.private_key_path = ENV["RS_PRIVATE_KEY"]
    rs.username = ENV["RS_USERNAME"]
    rs.api_key  = ENV["RS_API_KEY"]
    rs.public_key_path = ENV["RS_PUBLIC_KEY"]
    rs.flavor   = /512MB/
    rs.image    = /Ubuntu/
  end

  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box = BOX_NAME
    override.vm.box_url = VF_BOX_URI
    override.vm.synced_folder ".", "/vagrant", disabled: true
    f.vmx["displayName"] = "docker"
  end

  config.vm.provider :virtualbox do |vb|
    config.vm.box = BOX_NAME
    config.vm.box_url = BOX_URI
  end
end

if !FORWARD_DOCKER_PORTS.nil?
  Vagrant::VERSION < "1.1.0" and Vagrant::Config.run do |config|
    (49000..49900).each do |port|
      config.vm.forward_port port, port
    end
  end

  Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
    (49000..49900).each do |port|
      config.vm.network :forwarded_port, :host => port, :guest => port
    end
  end
end
