# Module:: scenario
# Manifest:: openstack/neutron.pp
#

class scenario::openstack::neutron (
  String $admin_password            = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address
) inherits scenario::openstack::params {

  class {'::scenario::common::neutron':
    controller_public_address => $controller_public_address
  }

  class { '::neutron::db::mysql':
    password => 'neutron',
    # TODO be more restrictive on the grants
    allowed_hosts => ['localhost', '127.0.0.1', '%']
  }
  class { '::neutron::keystone::auth':
    password     => $admin_password,
    public_url   => "http://${controller_public_address}:9696",
    internal_url => "http://${controller_public_address}:9696",
    admin_url    => "http://${controller_public_address}:9696"
  }

  class { '::neutron::client': }
  class { '::neutron::server':
    database_connection => "mysql://neutron:neutron@${controller_public_address}/neutron?charset=utf8",
    auth_password       => $admin_password,
    identity_uri        => "http://${controller_public_address}:35357/",
    auth_uri            => "http://${controller_public_address}:5000",
    sync_db             => true,
  }

  class { '::neutron::server::notifications':
    username    => 'nova',
    tenant_name => 'services',
    password    => $admin_password,
    nova_url    => "http://${controller_public_address}:8774/v2",
    auth_url    => "http://${controller_public_address}:35357",
    region_name => "RegionOne"
  }

  class { '::neutron::agents::ml2::ovs':
    enable_tunneling => true,
    local_ip         => $controller_public_address,
    #local_ip         => ip_for_network($data_network),
    tunnel_types     => ['vxlan'],
    bridge_mappings  => ["public:br-ex"],
  }
  class { '::neutron::agents::metadata':
    debug         => true,
    auth_password => $admin_password,
    shared_secret => $admin_password,
    auth_url      => "http://${controller_public_address}:35357/v2.0",
    metadata_ip   => $controller_public_address
  }
  class { '::neutron::agents::l3':
    debug => true,
  }
  class { '::neutron::agents::dhcp':
    # dnsmasq_config_file => '/etc/dnsmasq.conf',
    debug => true,
  }
  class { '::neutron::agents::metering':
    debug => true,
  }

  # Fix for SSH: network packet size
  class { '::neutron::agents::dhcp':
    dnsmasq_config_file => '/etc/dnsmasq.conf',
    debug               => true,
  }
  file { '/etc/dnsmasq.conf':
    ensure => present,
    source => "puppet:///modules/scenario/dnsmasq.conf",
    notify => Service["neutron-dhcp-agent"]
  }
}
