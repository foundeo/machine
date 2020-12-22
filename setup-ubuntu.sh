#!/bin/bash

echo "UPDATE / UPGRADE APT Packages"
#update packages
apt update
apt upgrade

echo "Install CommandBox"
#pre-requisites for commandbox
apt install curl apt-transport-https ca-certificates gnupg openjdk-11-jdk-headless 

#install commandbox
curl -fsSl https://downloads.ortussolutions.com/debs/gpg | apt-key add -
echo "deb https://downloads.ortussolutions.com/debs/noarch /" | tee -a /etc/apt/sources.list.d/commandbox.list
apt update && apt install commandbox

#OPTIONAL
echo "Install Optional Packages: install nginx, git, certbot, unattended-upgrades "
apt install nginx git certbot unattended-upgrades

