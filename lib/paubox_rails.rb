require "paubox_rails/version"
require 'action_mailer'
require 'paubox'

module PauboxRails
  extend self

  def install
    ActionMailer::Base.add_delivery_method :paubox, Mail::Paubox
  end
end

if defined?(Rails)
  require 'paubox-rails/railtie'
else
  PauboxRails.install
end