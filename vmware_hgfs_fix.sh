#!/bin/sh -x
cd /tmp
sudo apt-get install -y unzip
git clone https://github.com/rasa/vmware-tools-patches.git
cd vmware-tools-patches
sudo ./download-tools.sh 7.1.1
sudo ./untar-and-patch-and-compile.sh
