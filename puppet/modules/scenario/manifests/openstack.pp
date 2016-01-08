# Module:: scenario
# Manifest:: openstack.pp
#

class scenario::openstack (
  String $package_provider  = $scenario::openstack::params::package_provider,
  String $admin_password    = $scenario::openstack::params::admin_password,
  String $primary_interface = $scenario::openstack::params::primary_interface
) inherits scenario::openstack::params {
}
