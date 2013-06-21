# Install Java
include_recipe "java"

# Install PostgreSQL, including locale, user and database
execute "add-locale" do
  command "locale-gen #{node["teamcity-server"]["postgresql"]["locale"]}"
end
include_recipe "postgresql::server"

# Install Git
include_recipe "git"

# Install TeamCity Server
server_archive = "TeamCity-#{node["teamcity-server"]["version"]}.tar.gz"
server_directory = "/opt"
remote_file "#{server_directory}/#{server_archive}" do
  backup false
  source "http://download.jetbrains.com/teamcity/#{server_archive}"
  action :create_if_missing
  notifies :run, "execute[install-teamcity]", :immediately
end
execute "install-teamcity" do
  command "tar -xvf #{server_archive}"
  cwd server_directory
  action :nothing
end

# Configure TeamCity Server
config_directory = "#{server_directory}/TeamCity/conf"
template "#{config_directory}/server.xml" do
  source "server.xml.erb"
  variables(
    :address => node["teamcity-server"]["address"],
    :port => node["teamcity-server"]["port"]
  )
end

data_directory = "/root/.BuildServer"
jdbc_driver_filename = "postgresql-#{node["teamcity-server"]["postgresql"]["driver_version"]}.jdbc4.jar"
jdbc_driver_directory = "#{data_directory}/lib/jdbc"
directory jdbc_driver_directory do
  recursive true
  action :create
end
remote_file "#{jdbc_driver_directory}/#{jdbc_driver_filename}" do
  backup false
  mode 00644
  source "http://jdbc.postgresql.org/download/#{jdbc_driver_filename}"
  action :create_if_missing
end

data_config_directory = "#{data_directory}/config"
directory data_config_directory do
  recursive true
  action :create
end
cookbook_file "#{data_config_directory}/database.properties" do
  source "database.properties"
  action :create_if_missing
end

# Start TeamCity Service
cookbook_file "/etc/init/teamcity-server.conf" do
  backup false
  source "init/teamcity-server.conf"
  action :create_if_missing
end
service "teamcity-server" do
  provider Chef::Provider::Service::Upstart
  action :start
end
