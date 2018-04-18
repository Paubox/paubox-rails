require "paubox_rails/version"
require 'action_mailer'
require 'paubox'

module PauboxRails
  extend self

  def add_base_delivery
    ActionMailer::Base.add_delivery_method :paubox, Mail::Paubox
  end
end

if defined?(Rails)
  require 'paubox_rails/railtie'
else
  PauboxRails.add_base_delivery
end