require 'bundler/setup'
require 'rubygems'
require 'paubox'
require 'paubox_rails'
require 'fixtures/models/test_mailer.rb'
require 'pry'

ActionMailer::Base.delivery_method = :paubox
ActionMailer::Base.prepend_view_path("#{File.dirname(__FILE__)}/fixtures/views")
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

