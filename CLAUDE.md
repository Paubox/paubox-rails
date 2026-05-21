# CLAUDE.md — paubox-rails codebase guide

## What this gem does

`paubox-rails` is a thin Rails adapter gem with two responsibilities:

1. **Email delivery** — Registers `:paubox` as an ActionMailer delivery method, delegating all sending to the [`paubox`](https://github.com/paubox/paubox_ruby) gem (`Mail::Paubox`).
2. **Forms API client** — Provides `PauboxRails::Forms::Client` for interacting with the Paubox Forms public API (no auth required).

## Key files

```
lib/
  paubox_rails.rb               # Entry point: requires all components, registers delivery method
  paubox_rails/
    version.rb                  # VERSION constant
    railtie.rb                  # Rails hook — registers delivery method before ActionMailer boots
    forms.rb                    # PauboxRails::Forms module: BASE_URL, error classes, .client factory
    forms/
      client.rb                 # Forms HTTP client (Net::HTTP, no extra deps)
spec/
  paubox_rails_spec.rb          # Integration tests for ActionMailer delivery
  paubox_rails/
    forms/
      client_spec.rb            # Unit tests for Forms::Client (Net::HTTP stubs)
  fixtures/
    models/test_mailer.rb       # Minimal ActionMailer subclass used in tests
    views/test_mailer/          # ERB template for the test mailer
```

## Architecture

```
paubox-rails
├── Email path
│   ActionMailer → Mail::Paubox (from paubox gem) → RestClient → api.paubox.net
└── Forms path
    PauboxRails::Forms::Client → Net::HTTP → apx.paubox.com/forms
```

- Email credentials (`api_key`, `api_user`) are configured via `Paubox.configure`.
- Forms endpoints are **public** — no credentials needed.

## Running tests

```bash
bundle install
bundle exec rspec
```

## How to add a new Forms endpoint

1. Add a method to `lib/paubox_rails/forms/client.rb` following the `get_form` / `submit_form` pattern.
2. Use `build_http(uri)` to get an SSL-ready `Net::HTTP` instance.
3. Call `handle_response(response)` for consistent error handling.
4. Add corresponding tests in `spec/paubox_rails/forms/client_spec.rb`, stubbing `Net::HTTP.new` via `instance_double`.
5. Document the new method in `api.md` and `README.md`.

## How to add a new email feature

Email functionality lives in the `paubox` gem (not here). This gem only bridges ActionMailer to `Mail::Paubox`. To add email features, update the `paubox` gem and bump its version constraint in `paubox_rails.gemspec`.

## Version

Current: `0.2.0` (in `lib/paubox_rails/version.rb`)

- `0.1.x` — Initial releases, email delivery only
- `0.2.0` — Added Paubox Forms API support
