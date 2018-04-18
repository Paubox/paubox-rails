module PauboxRails
  class Railtie < Rails::Railtie
    initializer 'paubox-rails', :before => 'action_mailer.set_configs' do
      ActiveSupport.on_load :action_mailer do
        PauboxRails.install
      end
    end
  end
end
