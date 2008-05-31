set :application, "snplotyper"
set :repository,  "git@github.com:simont/snplotyper.git"
set :host, 'localhost'

# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
# set :deploy_to, "/var/www/#{application}"

# If you aren't using Subversion to manage your source code, specify
# your SCM below:
set :scm, :git
set :deploy_via, :remote_cache

set :mongrel_conf, "#{current_path}/config/mongrel_cluster.yml"

ssh_options[:paranoid] = false
set :user, 'simont'
set :runner, 'simont'
set :use_sudo, true

role :app, host
role :web, host
role :db,  host, :primary => true

set :deploy_to, "/Users/simont/Documents/Websites/test_sites/#{application}_production"


# Moves over server config files after deploying the code
task :update_config, :roles => [:app] do
  run "cp -Rf #{shared_path}/config/* #{release_path}/config"
end
after "deploy:update_code", :update_config