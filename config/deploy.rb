# coding: utf-8
require "bundler/capistrano"
require "sidekiq/capistrano"

require "rvm/capistrano"
default_run_options[:pty] = true
set :rvm_ruby_string, 'ruby-2.0.0-p0'
set :rvm_type, :user

set :application, "awsug-tw"
set :repository,  "git@github.com:AWSUG-TW/awsug-tw.git"
set :branch, "master"
set :scm, :git
set :user, "deployer"
if ENV["DEPLOY"] == "pre"
  set :deploy_to, "/home/deployer/#{application}-pre"
else
  set :deploy_to, "/home/deployer/#{application}"
end
set :runner, "ruby"
set :deploy_via, :remote_cache
set :git_shallow_clone, 1

role :web, "www.awsug.tw"                          # Your HTTP server, Apache/etc
role :app, "www.awsug.tw"                          # This may be the same as your `Web` server
role :db,  "www.awsug.tw", :primary => true # This is where Rails migrations will run

# unicorn.rb 路径
set :unicorn_path, "#{deploy_to}/current/config/unicorn.rb"

namespace :deploy do
  task :start, :roles => :app do
    run "cd #{deploy_to}/current/; RAILS_ENV=production bundle exec unicorn_rails -c #{unicorn_path} -D"
  end

  task :stop, :roles => :app do
    run "kill -QUIT `cat #{deploy_to}/current/tmp/pids/unicorn.pid`"
  end

  desc "Restart Application"
  task :restart, :roles => :app do
    run "kill -USR2 `cat #{deploy_to}/current/tmp/pids/unicorn.pid`"
  end
end

namespace :faye do
  desc "Start Faye"
  task :start, :roles => :app do
    run "cd #{deploy_to}/current/faye_server; thin start -C thin.yml"
  end

  desc "Stop Faye"
  task :stop, :roles => :app do
    run "cd #{deploy_to}/current/faye_server; thin stop -C thin.yml"
  end

  desc "Restart Faye"
  task :restart, :roles => :app do
    run "cd #{deploy_to}/current/faye_server; thin restart -C  thin.yml"
  end
end


task :init_shared_path, :roles => :web do
  run "mkdir -p #{deploy_to}/shared/log"
  run "mkdir -p #{deploy_to}/shared/pids"
  run "mkdir -p #{deploy_to}/shared/assets"
  run "mkdir -p #{deploy_to}/shared/tmp/sockets"
  run "mkdir -p #{deploy_to}/shared/config/initializers"

end

task :link_shared_files, :roles => :web do
  put File.read("config/nginx.conf"), "#{deploy_to}/shared/config/nginx.conf"
  sudo "ln -nfs #{deploy_to}/shared/config/nginx.conf /etc/nginx/sites-enabled/#{application}"

  put File.read("config/config.yml"), "#{deploy_to}/shared/config/config.yml"
  put File.read("config/mongoid.yml"), "#{deploy_to}/shared/config/mongoid.yml"
  put File.read("config/redis.yml"), "#{deploy_to}/shared/config/redis.yml"
  put File.read("config/thin.yml"), "#{deploy_to}/shared/config/thin.yml"
  put File.read("config/unicorn.rb"), "#{deploy_to}/shared/config/unicorn.rb"
  put File.read("faye_server/thin.yml"), "#{deploy_to}/shared/config/faye_thin.yml"
  put File.read("config/initializers/secret_token.rb"), "#{deploy_to}/shared/config/initializers/secret_token.rb"
  
  run "ln -sf #{deploy_to}/shared/config/*.yml #{deploy_to}/current/config/"
  run "ln -sf #{deploy_to}/shared/config/unicorn.rb #{deploy_to}/current/config/"
  run "ln -sf #{deploy_to}/shared/config/initializers/secret_token.rb #{deploy_to}/current/config/initializers"
  run "ln -sf #{deploy_to}/shared/config/faye_thin.yml #{deploy_to}/current/faye_server/thin.yml"
end

after "deploy:setup", "init_shared_path"
after "deploy:setup", "link_shared_files"

task :mongoid_create_indexes, :roles => :web do
  run "cd #{deploy_to}/current/; RAILS_ENV=production bundle exec rake db:mongoid:create_indexes"
end

task :compile_assets, :roles => :web do
  run "cd #{deploy_to}/current/; RAILS_ENV=production bundle exec rake assets:precompile"
end

task :sync_assets_to_cdn, :roles => :web do
  run "cd #{deploy_to}/current/; RAILS_ENV=production bundle exec rake assets:cdn"
end


task :mongoid_migrate_database, :roles => :web do
  run "cd #{deploy_to}/current/; RAILS_ENV=production bundle exec rake db:migrate"
end

after "deploy:finalize_update","deploy:symlink", :init_shared_path, :link_shared_files, :compile_assets#, :sync_assets_to_cdn, :mongoid_migrate_database
