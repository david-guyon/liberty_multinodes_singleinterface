#!/bin/sh

#set -x

# Can be commented when modules are available locally
echo "Setup the modules"
r10k -v info puppetfile install 

echo "Bring up standard OpenStack nodes"
vagrant up puppetmaster controller compute
wait

echo "Setup Puppetmaster node"
vagrant ssh puppetmaster -c "
sudo rmdir /etc/puppetlabs/code/modules || sudo unlink /etc/puppetlabs/code/modules; \
sudo ln -s /openstack/puppet/modules /etc/puppetlabs/code/modules; \
sudo service puppetmaster start; \
sudo puppet agent --enable; \ 
sudo puppet agent -t;"

echo "Setup Controller node"
vagrant ssh controller -c "sudo puppet agent --enable"
vagrant ssh controller -c "sudo puppet agent -t"

echo "Setup Compute node"
vagrant ssh compute -c "sudo puppet agent --enable"
vagrant ssh compute -c "sudo puppet agent -t"

echo "Sign the certs"
vagrant ssh puppetmaster -c "sudo puppet cert sign --all"

echo "Deploy Controller and configure network"
# the bridge isn't weel configured by the recipes, we explicity configure one before launching the puppet run
vagrant ssh controller -c "
sudo apt-get update && sudo apt-get -y install openvswitch-switch; \
sudo ovs-vsctl add-br brex && sudo ovs-vsctl add-port brex eth1 && sudo ifconfig eth1 0.0.0.0 && sudo ifconfig brex 12.168.0.6; \
sudo puppet agent -t"
wait

echo "Deploy Compute"
vagrant ssh compute -c "sudo puppet agent -t"
wait
