#!/usr/bin/env bash

echo "Puppetmaster installation script"

# Puppetmaster

echo "Getting puppetlabs-release-trusty.deb ..."
sudo wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb 2> /dev/null
echo "Done!"

sudo dpkg -i puppetlabs-release-trusty.deb
sudo apt-get update

sudo apt-get -y install puppetserver puppet-agent 2> /dev/null
sudo sed -i -e 's/Xms2g/Xms512m/g' /etc/default/puppetserver 
sudo sed -i -e 's/Xmx2g/Xmx512m/g' /etc/default/puppetserver 
