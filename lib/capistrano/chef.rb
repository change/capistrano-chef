require 'capistrano'
require 'chef/knife'
require 'chef/data_bag_item'
require 'chef/search/query'

module Capistrano::Chef
  # Set up chef configuration
  def self.configure_chef
    knife        = Chef::Knife.new
    # If you don't do this it gets thrown into debug mode
    knife.config = { :verbosity => 1 }
    knife.configure_chef
  end

  # Do a search on the Chef server and return an attary of the requested
  # matching attributes
  def self.search_chef_nodes(query = '*:*')
    Chef::Search::Query.new.search(:node, query)[0]
  end

  def self.get_data_bag_item(id, data_bag = :apps)
    Chef::DataBagItem.load(data_bag, id).raw_data
  end

  # Load into Capistrano
  def self.load_into(configuration)
    self.configure_chef
    configuration.set :capistrano_chef, self
    configuration.load do
      def chef_role(name, query = '*:*', options = { })
        capistrano_chef.search_chef_nodes(query).each do |server|
          opts_clone = options.clone
          attribute = opts_clone.delete(:attribute)
          opts_clone.merge!(name_suffix: server.name.split("#{host_prefix}-").last) if exists? :host_prefix
          role name, server[attribute], opts_clone
        end

      end

      def set_from_data_bag(data_bag = :apps)
        raise ':application must be set' if fetch(:application).nil?
        capistrano_chef.get_data_bag_item(application, data_bag).each do |k, v|
          set k, v
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Chef.load_into(Capistrano::Configuration.instance)
end
