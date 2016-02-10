
namespace :prepare do

  desc 'Prepare software on controller'
  task :controller do
    on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
      cmd = []
      cmd << 'apt-get install --yes git'
      cmd << 'git clone https://davidguyon@bitbucket.org/davidguyon/greenerbar.git'
      cmd << 'cd greenerbar ; bash install-greenerbar.bash'
      cmd
    end
  end
end
