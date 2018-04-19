# PauboxRails

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

TODO: Write usage instructions here


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/paubox_rails.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

