# Module:: scenario
# Manifest:: openstack/rabbitmq.pp
#

class scenario::openstack::rabbitmq (
  String $package_provider = $scenario::openstack::params::package_provider,
) inherits scenario::openstack::params {

  class { '::rabbitmq':
    delete_guest_user => true,
    package_provider  => $package_provider,
  }
  rabbitmq_vhost { '/':
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }
  rabbitmq_user { ['neutron', 'nova', 'glance', 'ceilometer']:
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['rabbitmq'],
  }
  rabbitmq_user_permissions { ['neutron@/', 'nova@/', 'glance@/', 'ceilometer@/']:
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['rabbitmq'],
  }
}
