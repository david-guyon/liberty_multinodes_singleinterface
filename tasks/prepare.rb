
namespace :prepare do

  desc 'Prepare software on controller and computes'
  task :main do
    Rake::Task['prepare:controller']
    Rake::Task['prepare:computes']
  end

  desc 'Prepare software on controller'
  task :controller do
    workflow = [
      'prepare:controller_side:send_job_status',
      'prepare:controller_side:ssh_key',
      'prepare:controller_side:greenerbar',
      'prepare:controller_side:fix_tiny',
      'prepare:controller_side:rm_xs',
      'prepare:controller_side:img_workflows',
      'prepare:controller_side:frieda',
      'prepare:controller_side:user_upload'
    ]
    workflow.each do |task|
      Rake::Task[task].execute
    end
  end

  desc 'Prepare software on computes'
  task :computes do
    workflow = [
      'prepare:compute_side:hello_world'
    ]
    workflow.each do |task|
      Rake::Task[task].execute
    end
  end

  namespace :controller_side do

    desc 'Send job status'
    task :send_job_status do
      sh %{oarstat -Yu > /home/dguyon/job_status.yaml}
      controller_node = roles('controller').first
      sh %{scp /home/dguyon/job_status.yaml root@#{controller_node}:}
    end

    desc 'Prepare SSH key'
    task :ssh_key do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << 'ssh-keygen -t rsa -m pem -f ssh_key.pem -N ""'
        cmd << 'nova keypair-add --pub_key ~/ssh_key.pem.pub ssh_key'
        cmd
      end
    end

    desc 'Git clone the GreenerBar'
    task :greenerbar do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << 'apt-get install --yes git'
        cmd << 'git clone https://davidguyon@bitbucket.org/davidguyon/greenerbar.git'
        cmd << 'cd greenerbar ; bash install-greenerbar.bash'
        cmd
      end
    end

    desc 'Fix tiny flavor'
    task :fix_tiny do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << 'nova flavor-delete m1.tiny'
        cmd << 'nova flavor-create m1.tiny 1 512 5 1'
        cmd
      end
    end

    desc 'Rm xs flavor'
    task :rm_xs do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << 'nova flavor-delete m1.xs'
        cmd
      end
    end

    desc 'Add images for workflows'
    task :img_workflows do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << '/usr/bin/wget -q -O /tmp/debian-palmtree.img http://public.rennes.grid5000.fr/~dguyon/images/debian-palmtree.img'
        cmd << 'glance image-create --name="Debian Palmtree" --disk-format=qcow2 --container-format=bare --property architecture=x86_64 --progress --file /tmp/debian-palmtree.img' 
        cmd
      end
    end

    desc 'Setup FRIEDA'
    task :frieda do
      controller_node = roles('controller').first
      sh %{scp -r /home/dguyon/FRIEDA root@#{controller_node}:}
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << 'echo "export EC2_KEYPAIR=ssh_key" >> ~/.bashrc'
        cmd << 'echo "export EC2_SECURITY_GROUP=default" >> ~/.bashrc'
        cmd << 'cd FRIEDA ; ./setup.py build ; ./setup.py install'
        cmd
      end
    end

    desc 'Prepare user upload'
    task :user_upload do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << 'adduser upload --disabled-password --gecos ""'
        cmd << 'su upload -c "cd && mkdir .ssh && 
                              ssh-keygen -t rsa -f .ssh/id_rsa -q -N \"\" &&
                              cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"'
        cmd << 'mkdir /home/upload/upload_files'
        cmd << 'mkdir /tmp/upload_files'
        cmd << 'mount -o bind /tmp/upload_files/ /home/upload/upload_files/'
        cmd << 'chown upload /home/upload/upload_files/'
        cmd
      end
    end
  end

  namespace :compute_side do

    desc 'Prepare software on computes'
    task :hello_world do
      on(roles('compute'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << 'echo "Hello World!"'
        cmd
      end
    end
  end
end
