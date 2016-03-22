#!/bin/sh -x
cd /tmp
sudo apt-get install -y unzip git
git clone https://github.com/rasa/vmware-tools-patches.git
cd vmware-tools-patches
sudo ./download-tools.sh 8.1.0
sudo ./untar-and-patch-and-compile.sh
