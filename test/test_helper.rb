if File.exist?("../../../config/boot.rb")
  require "../../../config/boot.rb"
else
  require 'rubygems'
end

gem 'activesupport', ENV['RAILS_VERSION']
gem 'activerecord',  ENV['RAILS_VERSION']

require 'minitest/autorun'
require 'active_support'
require 'active_support/test_case'
require 'active_record'
require 'active_record/fixtures'

begin
  require 'byebug'
rescue LoadError
  # no debugging for you
end

RAILS_ROOT = File.dirname(__FILE__)
RAILS_ENV = ENV['RAILS_ENV'] ||= 'test'
TEST_TEMP_DIR = File.join(File.dirname(__FILE__), 'tmp', 'attachment_saver_test')

class Rails
  def self.root; RAILS_ROOT; end
  def self.env;  RAILS_ENV;  end
end

class DummyLogger
  def method_missing(*args)
  end
end

ActiveRecord::Base.logger = DummyLogger.new

ActiveRecord::Base.configurations = YAML::load(IO.read(File.join(File.dirname(__FILE__), "database.yml")))
ActiveRecord::Base.establish_connection ActiveRecord::Base.configurations[ENV['RAILS_ENV']]
load(File.join(File.dirname(__FILE__), "/schema.rb"))

require File.expand_path(File.join(File.dirname(__FILE__), '../init')) # load the plugin

at_exit do
  FileUtils.rm_rf(File.join(File.dirname(__FILE__), 'tmp'))
end
