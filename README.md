# Paubox Rails

#### This gem, Paubox Ruby, and Paubox Transactional Email HTTP API are currently in pre-alpha development.

This gem extends the [Paubox Ruby Gem](https://github.com/paubox/paubox_ruby) for use with ActionMailer in Ruby on Rails. Paubox Ruby the official Ruby wrapper for the Paubox Transactional Email HTTP API. The Paubox Transactional Email API allows your application to send secure, HIPAA-compliant email via Paubox and track deliveries and opens.

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
You will need to have a Paubox account. Please contact [Paubox Customer Success](https://paubox.zendesk.com/hc/en-us) for details on gaining access to the Transactional Email API alpha testing program.


### Configuring API Credentials
Create a new file at config/initializers/paubox.rb and add the following.
 
	Paubox.configure do |config|
     config.api_key = ENV['PAUBOX_API_KEY']
     config.api_user = ENV['PAUBOX_API_USER']
    end

Keep your API credentials out of version control. Set these environmental variables in a file that's not checked into version control, such as config/application.yml or config/secrets.yml.


### Setting ActionMailer Delivery Method

Add the following to the configuration block in config/application.rb or the desired environment config in config/environments (e.g. config/environments/production.rb for production.)

    config.action_mailer.delivery_method = :paubox
    

## Usage

See the [Paubox Ruby Gem](https://github.com/Paubox/paubox_ruby) for usage examples.


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