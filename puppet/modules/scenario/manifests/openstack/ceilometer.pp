# Module:: scenario
# Manifest:: openstack/ceilometer.pp
#

class scenario::openstack::ceilometer (
  String $admin_password            = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
) inherits scenario::openstack::params {

  class { '::ceilometer::db::mysql':
    password      => 'ceilometer',
    # TODO be more restrictive on the grants
    allowed_hosts => ['localhost', '127.0.0.1', '%']
  }

  class { '::scenario::common::ceilometer':
    controller_public_address => $controller_public_address,
  }

  class { '::ceilometer::db':
    database_connection => "mysql://ceilometer:ceilometer@${controller_public_address}/ceilometer?charset=utf8",
  }

  class { '::ceilometer::agent::auth':
    auth_url      => "http://${controller_public_address}:35357/v2.0",
    auth_password => $admin_password,
  }

  class { '::ceilometer::api':
    enabled               => true,
    keystone_password     => $admin_password,
    keystone_identity_uri => "http://${controller_public_address}:35357",
  }

  class { '::ceilometer::keystone::auth':
    service_type => 'metering',
    password     => $admin_password,
    public_url   => "http://${controller_public_address}:8777",
    internal_url => "http://${controller_public_address}:8777",
    admin_url    => "http://${controller_public_address}:8777"
  }

  class { '::ceilometer::client': }
  class { '::ceilometer::collector': }
  class { '::ceilometer::expirer': }
  class { '::ceilometer::alarm::evaluator': }
  class { '::ceilometer::alarm::notifier': }
}
