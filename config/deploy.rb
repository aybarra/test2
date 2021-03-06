# Application Specific Details
set :application, "test2"
set :domain, "localhost"
set :deploy_via, :remote_cache
set :repository,  "git@github.com:aybarra/test2.git"
set :scm, :git
set :scm_username, "aybarra"
set :scm_password, "aA187759!"
set :use_sudo, false
## Magic Starts. N.B. You can set variables before if you'd like

# Suitable for a vps-style system
# where each part is on the same domain.

# Location
set :deploy_to, "/usr2/aybarra/deployed/#{application}"

# Deployment details
set :user,   "aybarra"      unless exists?(:user)
set :password, "aA187759!"
set :runner, user          unless exists?(:runner)
set :server_type, :mongrel    unless exists?(:server_type)
set :deploy_port, 8000     unless exists?(:deploy_port)
set :cluster_instances, 3  unless exists?(:cluster_instances)
set :use_sqlite3, true     unless exists?(:use_sqlite)
set :keep_releases, 3      unless exists?(:keep_releases)



# Paths
set :shared_database_path,        "#{shared_path}/databases"
set :shared_config_path,          "#{shared_path}/configs"
set :shared_uploaded_images_path, "#{shared_path}/uploaded_images"
set :public_uploaded_images_path, "#{current_path}/public/images/uploaded"

# Our helper methods

def public_configuration_location_for(server = :thin)
  "#{current_path}/config/#{server}.yml"
end

def shared_configuration_location_for(server = :thin)
  "#{shared_config_path}/#{server}.yml"
end

# Our Server Roles
role :app, domain.to_s
role :web, domain.to_s
role :db,  domain.to_s, :primary => true

namespace :configuration do

  desc "Links the local copies of the shared images folder"
  task :localize, :roles => :app do
    run "rm -rf  #{public_uploaded_images_path}" # God. Damned. Reversing it removes ALL images. Not fun.
    run "ln -nsf #{shared_uploaded_images_path} #{public_uploaded_images_path}"
  end

  desc "Makes link for database"
  task :make_default_folders, :roles => :app do
    run "mkdir -p #{shared_config_path}"
    run "mkdir -p #{shared_uploaded_images_path}"
  end

end

# Application Server Choices

namespace :mongrel do

  desc "Generate a mongrel configuration file"
  task :build_configuration, :roles => :app do
    config_options = {
      "user"        => (runner || user),
      "group"       => (runner || user),
      "log_file"    => "#{current_path}/log/mongrel.log",
      "cwd"         => current_path,
      "port"        => deploy_port,
      "servers"     => cluster_instances,
      "environment" => "production",
      "address"     => "localhost",
      "pid_file"    => "#{current_path}/tmp/pids/mongrel.pid"
    }.to_yaml
    put config_options, shared_configuration_location_for(:mongrel)
  end

  desc "Links the configuration file"
  task :link_configuration_file, :roles => :app do
    run "ln -nsf #{shared_configuration_location_for(:mongrel)} #{public_configuration_location_for(:mongrel)}"
  end

  desc "Setup Mongrel Cluster After Code Update"
  task :link_global_configuration, :roles => :app do
    run "ln -nsf /etc/mongrel_cluster/#{application}.yml"
  end

  %w(start stop restart).each do |action|
  desc "#{action} this app's Mongrel Cluster"
    task action.to_sym, :roles => :app do
      run "mongrel_rails cluster::#{action} -C #{shared_configuration_location_for(:mongrel)}"
    end
  end

end

namespace :thin do

  desc "Generate a thin configuration file"
  task :build_configuration, :roles => :app do
    config_options = {
      "user"        => (runner || user),
      "group"       => (runner || user),
      "log"    => "#{current_path}/log/thin.log",
      "chdir"         => current_path,
      "port"        => deploy_port,
      "servers"     => cluster_instances.to_i,
      "environment" => "production",
      "address"     => "localhost",
      "pid"    => "#{current_path}/tmp/pids/log.pid"
    }.to_yaml
    put config_options, shared_configuration_location_for(:thin)
  end

  desc "Links the configuration file"
  task :link_configuration_file, :roles => :app do
    run "ln -nsf #{shared_configuration_location_for(:thin)} #{public_configuration_location_for(:thin)}"
  end

  desc "Setup Thin Cluster After Code Update"
  task :link_global_configuration, :roles => :app do
    run "ln -nsf #{shared_configuration_location_for(:thin)} /etc/thin/#{application}.yml"
  end

  %w(start stop restart).each do |action|
  desc "#{action} this app's Thin Cluster"
    task action.to_sym, :roles => :app do
      run "thin #{action} -C #{shared_configuration_location_for(:thin)}"
    end
  end

end

# Our Database Stuff - currently only sqlite3
namespace :sqlite3 do

  desc "Generate a database configuration file"
  task :build_configuration, :roles => :db do
    db_options = {
      "adapter"  => "sqlite3",
      "database" => "db/production.sqlite3"
    }
    config_options = {"production" => db_options}.to_yaml
    put config_options, "#{shared_config_path}/sqlite_config.yml"
  end

  desc "Links the configuration file"
  task :link_configuration_file, :roles => :db do
    run "ln -nsf #{shared_config_path}/sqlite_config.yml #{current_path}/config/database.yml"
    run "touch #{shared_database_path}/production.sqlite3"
    run "ln -nsf #{shared_database_path}/production.sqlite3 #{current_path}/db/production.sqlite3"
  end

  desc "Make a shared database folder"
  task :make_shared_folder, :roles => :db do
    run "mkdir -p #{shared_database_path}"
  end

end

# Our Global Web Server - NGINX :D
namespace :nginx do
  desc "Start Nginx on the app server."
  task :start, :roles => :web do
    run "/etc/init.d/nginx start"
  end

  desc "Restart the Nginx processes on the app server by starting and stopping the cluster."
  task :restart , :roles => :web do
    run "/etc/init.d/nginx restart"
  end

  desc "Stop the Nginx processes on the app server."
  task :stop , :roles => :web do
    run "/etc/init.d/nginx stop"
  end

  desc "Stop the Nginx processes on the app server."
  task :reload , :roles => :web do
    run "/etc/init.d/nginx stop"
  end

  %w(start stop restart reload).each do |action|
    desc "#{action} the Nginx processes on the web server."
    task action.to_sym , :roles => :web do
      run "/etc/init.d/nginx #{action}"
    end
  end

end

# Our magic

namespace :deploy do

  %w(start stop restart).each do |action|
    desc "#{action} our server"
    task action.to_sym do
      find_and_execute_task("#{server_type}:#{action}")
    end
  end

end

# After Tasks
after "deploy:setup",   "configuration:make_default_folders"
after "deploy:setup",   "#{server_type}:build_configuration"

#after "#{server_type}:build_configuration", "#{server_type}:link_global_configuration"

after "deploy:symlink", "configuration:localize"
after "deploy:symlink", "#{server_type}:link_configuration_file"

if use_sqlite3
  after "deploy:setup", "sqlite3:make_shared_folder"
  after "deploy:setup", "sqlite3:build_configuration"
  after "deploy:symlink", "sqlite3:link_configuration_file"
end
