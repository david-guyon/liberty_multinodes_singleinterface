# Module:: scenario
# Manifest:: common/ceilometer.pp
#

class scenario::common::ceilometer (
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
) {

  # common config
  class { '::ceilometer':
    metering_secret  => 'ceilometer',
    rabbit_userid    => 'ceilometer',
    rabbit_password  => 'an_even_bigger_secret',
    rabbit_host      => $controller_public_address,
    debug            => true,
    verbose          => true,
  }
}
