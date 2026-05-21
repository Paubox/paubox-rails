<img src="https://avatars.githubusercontent.com/u/22528478?s=200&v=4" alt="Paubox" width="150px">

# Paubox Rails

This gem extends the [Paubox Ruby Gem](https://github.com/paubox/paubox_ruby) for use with ActionMailer in Ruby on Rails.

The Paubox Email API allows your application to send secure, HIPAA compliant email via Paubox and track deliveries and opens.

## Compatibility
This gem has been tested and confirmed working with Rails 4-6

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
You will need to have a Paubox account. You can [sign up here](https://www.paubox.com/pricing/paubox-email-api).

Once you have an account, follow the instructions on the Rest API dashboard to verify domain ownership and generate API credentials.

### Configuring API Credentials
Create a new file at config/initializers/paubox.rb and add the following.
```ruby
Paubox.configure do |config|
  config.api_key = ENV['PAUBOX_API_KEY']
  config.api_user = ENV['PAUBOX_API_USER']
end
```

Note: Keep your unencrypted API credentials out of version control. Set as environment variables in a file that's not checked into version control, such as config/application.yml or config/secrets.yml. Better yet, use Rails Encrypted Secrets.


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

## Paubox Forms

The gem includes a client for the [Paubox Forms API](https://docs.paubox.com/forms). These endpoints are **public** — no API key or authentication is required.

### Get form metadata

Retrieves a form's full definition (HTML, JSON schema, CSS, metadata).

```ruby
client = PauboxRails::Forms::Client.new
# or use the convenience factory:
client = PauboxRails::Forms.client

form = client.get_form('550e8400-e29b-41d4-a716-446655440000')
puts form['title']            # => "Patient Intake Form"
puts form['active']           # => true
puts form['submission_count'] # => 42
```

Raises `PauboxRails::Forms::NotFoundError` if the form UUID does not exist.

### Submit a form response

Submits a respondent's answers for a form. On success, Paubox stores the submission, increments the submission count, and emails recipients (if configured).

```ruby
client.submit_form(
  '550e8400-e29b-41d4-a716-446655440000',
  form_data: {
    first_name: 'Jane',
    last_name:  'Smith',
    email:      'jane@example.com'
  }
)
# => true
```

#### With file attachments

Attachments must be base64-encoded. Maximum request size is 250 MB.

```ruby
require 'base64'

client.submit_form(
  '550e8400-e29b-41d4-a716-446655440000',
  form_data: { first_name: 'Jane' },
  attachments: [
    {
      name:    'consent.pdf',
      content: Base64.strict_encode64(File.read('consent.pdf'))
    }
  ]
)
```

Raises `PauboxRails::Forms::BadRequestError` on a 400 response, or `PauboxRails::Forms::NotFoundError` if the form is not found.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paubox/paubox-rails.


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
Copyright &copy; 2022, Paubox, Inc.
