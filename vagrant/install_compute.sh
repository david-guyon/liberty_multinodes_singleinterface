#!/usr/bin/env bash

echo "Compute installation script"

# Compute

echo "Getting puppetlabs-release-trusty.deb ..."
sudo wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb 2> /dev/null
echo "Done!"

sudo dpkg -i puppetlabs-release-trusty.deb
sudo apt-get update
sudo apt-get -y install puppet-agent 2> /dev/null
