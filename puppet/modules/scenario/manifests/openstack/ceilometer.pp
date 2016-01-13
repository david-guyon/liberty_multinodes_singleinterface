# Module:: scenario
# Manifest:: openstack/ceilometer.pp
#

class scenario::openstack::ceilometer (
  String $admin_password            = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address
) inherits scenario::openstack::params {

  class { '::ceilometer':
    metering_secret  => 'ceilometer',
    rabbit_userid    => 'ceilometer',
    rabbit_password  => 'an_even_bigger_secret',
    rabbit_host      => $controller_public_address,
    debug            => true,
    verbose          => true,
  }

  class { '::ceilometer::db::mysql':
    password => 'ceilometer',
  }

  class { '::ceilometer::keystone::auth':
    password     => $admin_password,
    #public_url   => "http://${controller_public_address}:9696",
    #internal_url => "http://${controller_public_address}:9696",
    #admin_url    => "http://${controller_public_address}:9696"
  }

  class { '::ceilometer::client': }
  class { '::ceilometer::collector': }
  class { '::ceilometer::expirer': }
  class { '::ceilometer::alarm::evaluator': }
  class { '::ceilometer::alarm::notifier': }
  class { '::ceilometer::agent::central': }
  class { '::ceilometer::agent::notification': }
  class { '::ceilometer::db':
    database_connection => 'mysql://ceilometer:ceilometer@${controller_public_address}/ceilometer?charset=utf8',
  }

  class { '::ceilometer::api':
    debug                 => true,
    verbose               => true,
    enabled               => true,
    keystone_password     => $admin_password,
    keystone_identity_uri => "http://${controller_public_address}:35357",
  }

}
