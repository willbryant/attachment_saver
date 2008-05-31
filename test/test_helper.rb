require 'rubygems'

PROJECT_ROOT=File.expand_path("../../..")
if File.directory?("#{PROJECT_ROOT}/vendor/rails")
  require "#{PROJECT_ROOT}/vendor/rails/railties/lib/initializer"
end
require 'active_record'

begin
  require 'ruby-debug'
  Debugger.start
rescue
  # ruby-debug not installed, no debugging for you
end

RAILS_ROOT = File.dirname(__FILE__)
RAILS_ENV = ENV['RAILS_ENV'] ||= 'test'
TEST_TEMP_DIR = File.join(File.dirname(__FILE__), 'tmp', 'attachment_saver_test')
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "/log/#{ENV['RAILS_ENV']}.log"))

database_config = YAML::load(IO.read(File.join(File.dirname(__FILE__), '/database.yml')))
ActiveRecord::Base.establish_connection(database_config[ENV['RAILS_ENV']])
load(File.join(File.dirname(__FILE__), "/schema.rb"))

require 'init' # load attachment_saver

at_exit do # at_exits are run in reverse of declaration order, and Test::Unit runs from an at_exit, so we must declare ours before that jrequire below
  FileUtils.rm_rf(File.join(RAILS_ROOT, 'public', 'test'))
end

require 'test/unit'
