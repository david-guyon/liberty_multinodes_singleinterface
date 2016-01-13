# Module:: scenario
# Manifest:: openstack/ceilometer.pp
#

class scenario::openstack::ceilometer (
  String $admin_password            = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
) inherits scenario::openstack::params {

  class { '::ceilometer::db::mysql':
    password => 'ceilometer',
  }

  class { '::scenario::common::ceilometer':
    controller_public_address => $controller_public_address,
  }

  class { '::ceilometer::db':
    database_connection => "mysql://ceilometer:ceilometer@${controller_public_address}/ceilometer?charset=utf8",
  }

  class { '::ceilometer::api':
    enabled               => true,
    keystone_password     => $admin_password,
    keystone_identity_uri => "http://${controller_public_address}:35357",
  }

  class { '::ceilometer::keystone::auth':
    service_type => 'metering',
    password     => $admin_password,
    public_url   => "http://${controller_public_address}:9696",
    internal_url => "http://${controller_public_address}:9696",
    admin_url    => "http://${controller_public_address}:9696"
  }

  class { '::ceilometer::client': }
  class { '::ceilometer::collector': }
  class { '::ceilometer::expirer': }
  class { '::ceilometer::alarm::evaluator': }
  class { '::ceilometer::alarm::notifier': }
}
