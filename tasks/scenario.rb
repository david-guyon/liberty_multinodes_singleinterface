# Scenario dedicated Rake task
#

# Override OAR resources (tasks/jobs.rb)
# We uses 2 nodes (1 puppetserver and 1 controller) and a subnet for floating public IPs
#

XP5K::Config[:jobname]  ||= 'liberty_multinodes_singleinterface'
XP5K::Config[:site]     ||= 'rennes'
XP5K::Config[:walltime] ||= '1:00:00'
XP5K::Config[:cluster]  ||= ''
XP5K::Config[:vlantype] ||= 'kavlan-local'
XP5K::Config[:computes] ||= 1

# If cluster is defined
cluster = "and cluster='" + XP5K::Config[:cluster] + "'" if !XP5K::Config[:cluster].empty?

# 1 puppet node + 1 controller node + x compute nodes
nodes = 2 + XP5K::Config[:computes].to_i

# Resource request sent to the Grid'5000 API
resources = [] << %{{type='#{XP5K::Config[:vlantype]}'}/vlan=1+{virtual != 'none' #{cluster}}/nodes=#{nodes}+slash_22=1,walltime=#{XP5K::Config[:walltime]}}

@job_def[:resources] = resources
@job_def[:roles] << XP5K::Role.new({
  name: 'controller',
  size: 1,
  inner: 'puppetserver'
})

@job_def[:roles] << XP5K::Role.new({
  name: 'compute',
  size: XP5K::Config[:computes].to_i
})

G5K_NETWORKS = YAML.load_file("scenarios/liberty_multinodes_singleinterface/g5k_networks.yml")

# Override role 'all' (tasks/roles.rb)
#
role 'all' do
  roles 'puppetserver', 'controller', 'compute'
end


# Define OAR job (required)
#
xp.define_job(@job_def)


# Define Kadeploy deployment (required)
#
xp.define_deployment(@deployment_def)


namespace :scenario do

  # Required task
  desc 'Main task called at the end of `run` task'
  task :main do
    # install vlan (force cache regeneration before)
    Rake::Task['interfaces:cache'].execute
    # in this case, the vlan should be configured in the kadeploy configuration (see deployment.rb)
    #Rake::Task['interfaces:vlan'].execute
    Rake::Task['scenario:hiera:update'].execute
    
    # patch
    Rake::Task['scenario:os:patch'].execute
    Rake::Task['puppet:modules:upload'].execute

    # run controller recipes 
    # do not call rake task (due to chaining)
    puppetserver = roles('puppetserver').first
    on roles('controller') do
      cmd = "/opt/puppetlabs/bin/puppet agent -t --server #{puppetserver}"
      cmd += " --debug" if ENV['debug']
      cmd += " --trace" if ENV['trace']
      cmd
    end
    
    # run compute recipes
    on roles('compute') do
      cmd = "/opt/puppetlabs/bin/puppet agent -t --server #{puppetserver}"
      cmd += " --debug" if ENV['debug']
      cmd += " --trace" if ENV['trace']
      cmd
    end

    Rake::Task['scenario:bootstrap'].execute
  end

  def update_common_with_networks
    common = YAML.load_file("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/common.yaml")
    network = G5K_NETWORKS[XP5K::Config[:site]]['production']
    common['scenario::openstack::network'] = network

    File.open("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/common.yaml", 'w') do |file|
      file.puts common.to_yaml
    end
  end

  def update_common_with_ips() 
    interfaces = get_node_interfaces
    common = YAML.load_file("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/common.yaml")
    common['scenario::openstack::admin_password'] = XP5K::Config[:openstack_env][:OS_PASSWORD]
    # TODO loop
    controller = roles('controller').first
    common['scenario::openstack::controller_public_address'] = interfaces[controller]["public"]["ip"]

    File.open("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/common.yaml", 'w') do |file|
      file.puts common.to_yaml
    end
  end

  desc 'Bootstrap the installation' 
  task :bootstrap do
    workflow = [
      'scenario:os:rules',
      'scenario:os:public_bridge',
      'scenario:os:network',
      'scenario:os:horizon',
      'scenario:os:flavors',
      'scenario:os:images',
      'scenario:os:ceilometer_collector',
      'scenario:os:ceilometer_alarm_notifier',
      'scenario:os:ceilometer_polling',
      'scenario:horizon_access'
    ]
    workflow.each do |task|
      Rake::Task[task].execute
    end
  end

  desc 'Show SSH configuration to access Horizon'
  task :horizon_access do
    puts '** Launch this script on your local computer and open http://localhost:8080 on your navigator'
    puts '---'
    script = %{cat > /tmp/openstack_ssh_config <<EOF\n}
    script += %{Host *.grid5000.fr\n}
    script += %{  User #{ENV['USER']}\n}
    script += %{  ProxyCommand ssh -q #{ENV['USER']}@194.254.60.4 nc -w1 %h %p # Access South\n}
    script += %{EOF\n}
    script += %{ssh -F /tmp/openstack_ssh_config -N -L 8080:#{roles('controller').first}:8080 #{ENV['USER']}@frontend.#{XP5K::Config[:site]}.grid5000.fr &\n}
    script += %{HTTP_PID=$!\n}
    script += %{ssh -F /tmp/openstack_ssh_config -N -L 6080:#{roles('controller').first}:6080 #{ENV['USER']}@frontend.#{XP5K::Config[:site]}.grid5000.fr &\n}
    script += %{CONSOLE_PID=$!\n}
    script += %{trap 'kill -9 $HTTP_PID && kill -9 $CONSOLE_PID' 2\n}
    script += %{echo 'http://localhost:8080'\n}
    script += %{wait\n}
    puts script
    puts '---'
  end

  namespace :hiera do

    desc 'Update common.yaml with network information (controller/storage ips, networks adresses)'
    task :update do
      update_common_with_ips()
      update_common_with_networks()

      # upload the new common.yaml
      puppetserver_fqdn = roles('puppetserver').first
      sh %{cd scenarios/#{XP5K::Config[:scenario]}/hiera/generated && tar -cf - . | ssh#{SSH_CONFIGFILE_OPT} root@#{puppetserver_fqdn} 'cd /etc/puppetlabs/code/environments/production/hieradata && tar xf -'}
    end
  end

  namespace :os do
    
    desc 'Update default security group rules'
    task :rules do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        # Add SSH rule
        cmd = [] << 'nova secgroup-add-rule default tcp 22 22 0.0.0.0/0'
        # Add ICMP rule
        cmd << 'nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0'
        cmd
      end
    end

    desc 'Configure public bridge'
    task :public_bridge do
      controllerHostname = roles('controller').first.split('.').first
      clusterName = controllerHostname.split('-').first
      restfullyDatas = xp.connection.root
      .sites[XP5K::Config[:site].to_sym]
      .clusters[clusterName.to_sym]
      .nodes.select { |i| i['uid'] == controllerHostname }.first
      device = restfullyDatas['network_adapters'].select { |interface|
        interface['mounted'] == true
      }.first['device']
      on(roles('controller'), user: 'root') do
        %{ ovs-vsctl add-port br-ex #{device} && ip addr flush #{device} && dhclient -nw br-ex }
      end
    end

    desc 'Configure Openstack network'
    task :network do
      publicSubnet = G5K_NETWORKS[XP5K::Config[:site]]["subnet"]

      # Grid'5000 CIDR: 10.140.0.0/22 (Lyon site)
      reservedSubnet = xp.job_with_name(XP5K::Config[:jobname])['resources_by_type']['subnets'].first

      # Public IP range: 10.140.0.10 .. 10.140.0.100
      publicPool = IPAddr.new(reservedSubnet).to_range.to_a[10..100]
      publicPoolStart,publicPoolStop = publicPool.first.to_s,publicPool.last.to_s

      # Data network CIDR: 192.168.1.0/24
      privateCIDR = '192.168.1.0/24'

      # Privage IP range: 192.168.1.10 .. 192.168.1.100
      privatePool = IPAddr.new(privateCIDR).to_range.to_a[10..100]
      privatePoolStart,privatePoolStop = privatePool.first.to_s,privatePool.last.to_s

      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << %{neutron net-create public --shared --provider:physical_network external --provider:network_type flat --router:external True}
        cmd << %{neutron net-create private}
        cmd << %{neutron subnet-create public #{publicSubnet["cidr"]} --name public-subnet --allocation-pool start=#{publicPoolStart},end=#{publicPoolStop} --dns-nameserver 131.254.203.235 --gateway #{publicSubnet["gateway"]}  --disable-dhcp}
        cmd << %{neutron subnet-create private #{privateCIDR} --name private-subnet --allocation-pool start=#{privatePoolStart},end=#{privatePoolStop} --dns-nameserver 131.254.203.235} 
        cmd << %{neutron router-create main_router}
        cmd << %{neutron router-gateway-set main_router public}
        cmd << %{neutron router-interface-add main_router private-subnet}
        cmd
      end
    end

    desc 'Init horizon theme'
    task :horizon do
      on(roles('controller'), user: 'root') do
        %{/usr/share/openstack-dashboard/manage.py collectstatic --noinput && /usr/share/openstack-dashboard/manage.py compress --force}
      end
    end

    desc 'Get images'
    task :images do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        [
           %{/usr/bin/wget -q -O /tmp/cirros.img http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img},
           %{glance image-create --name="Cirros" --disk-format=qcow2 --container-format=bare --property architecture=x86_64 --progress --file /tmp/cirros.img},
           %{/usr/bin/wget -q -O /tmp/debian.img http://public.rennes.grid5000.fr/~dguyon/images/debian.img},
           %{glance image-create --name="Debian Jessie 64-bit" --disk-format=qcow2 --container-format=bare --property architecture=x86_64 --progress --file /tmp/debian.img}
        ]
      end
    end

    desc 'Add flavors'
    task :flavors do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        %{nova flavor-create m1.xs auto 2048 4 2 --is-public True}
      end
    end

    desc 'Patch horizon Puppet module'
    task :patch do
      sh %{sed -i '24s/apache2/httpd/' scenarios/liberty_multinodes_singleinterface/puppet/modules-openstack/horizon/manifests/params.pp}
    end

    desc 'Restart Ceilometer collector'
    task :ceilometer_collector do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        %{service ceilometer-collector restart}
      end
    end

    desc 'Restart Ceilometer alarm notifier'
    task :ceilometer_alarm_notifier do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        %{service ceilometer-alarm-notifier restart}
      end
    end

    desc 'Rate of Ceilometer meters'
    task :ceilometer_polling do
      on(roles('compute'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        %{sed -i "s/600/20/g" /etc/ceilometer/pipeline.yaml; service ceilometer-polling restart}
      end
    end
  end
end
