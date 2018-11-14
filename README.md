<img src="https://github.com/Paubox/paubox-csharp/raw/master/paubox_logo.png" alt="Paubox" width="150px">

# Paubox Rails

This gem extends the [Paubox Ruby Gem](https://github.com/paubox/paubox_ruby) for use with ActionMailer in Ruby on Rails. Paubox Ruby the official Ruby wrapper for the Paubox Transactional Email HTTP API. The Paubox Transactional Email API allows your application to send secure, HIPAA-compliant email via Paubox and track deliveries and opens.

This gem, Paubox Ruby, and Paubox Transactional Email HTTP API are currently in alpha development.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'paubox_rails'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install paubox_rails


### Getting Paubox API Credentials
You will need to have a Paubox account. You can [sign up here](https://www.paubox.com/join/see-pricing?unit=messages).

Once you have an account, follow the instructions on the Rest API dashboard to verify domain ownership and generate API credentials.

### Configuring API Credentials
Create a new file at config/initializers/paubox.rb and add the following.
```ruby
Paubox.configure do |config|
  config.api_key = ENV['PAUBOX_API_KEY']
  config.api_user = ENV['PAUBOX_API_USER']
end
```

Keep your API credentials out of version control. Set these environmental variables in a file that's not checked into version control, such as config/application.yml or config/secrets.yml.


### Setting ActionMailer Delivery Method

Add the following to the configuration block in config/application.rb or the desired environment config in config/environments (e.g. config/environments/production.rb for production.)
```ruby
config.action_mailer.delivery_method = :paubox
```

## Usage

You can use [Action Mailer](https://guides.rubyonrails.org/action_mailer_basics.html) as you normally would in a Rails app.

See the [Paubox Ruby Gem](https://github.com/Paubox/paubox_ruby) for more advanced usage examples.

## Allowing non-TLS message delivery with Action Mailer

Set ``allow_non_tls`` to true in the ``delivery_method_options`` hash argument and pass this into the mailer action.

For example:

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    @user = params[:user]
    @url  = user_url(@user)
    delivery_options = { allow_non_tls: true }
    mail(to: @user.email,
         subject: "Welcome!",
         delivery_method_options: delivery_options)
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paubox/paubox_rails.


## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Copyright
Copyright &copy; 2018, Paubox Inc.
