# CLAUDE.md — paubox-rails codebase guide

## What this gem does

`paubox-rails` is a thin Rails adapter gem with two responsibilities:

1. **Email delivery** — Registers `:paubox` as an ActionMailer delivery method, delegating all sending to the [`paubox`](https://github.com/paubox/paubox_ruby) gem (`Mail::Paubox`).
2. **Forms API client** — Provides `PauboxRails::Forms::Client` for interacting with the Paubox Forms API: public respondent endpoints (`get_form`, `submit_form` — no auth) plus authenticated form-management endpoints (list/create/update/archive/copy forms, stats, submissions, CSV/PDF export) that require a scoped API key with the `forms` scope, sent as `Authorization: Bearer`.

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
│   ActionMailer → Mail::Paubox (from paubox gem) → RestClient → api.paubox.com
└── Forms path
    PauboxRails::Forms::Client → Net::HTTP → api.paubox.com/forms
```

- Email credentials (`api_key`) are configured via `Paubox.configure`.
- Forms **respondent endpoints** (`get_form`, `submit_form`) are public — no credentials needed. All other Forms endpoints require a scoped API key (`forms` scope), passed via `Forms.client(api_key: ...)` or the `PAUBOX_FORMS_API_KEY` env var.

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

Current: `0.3.0` (in `lib/paubox_rails/version.rb`)

- `0.1.x` — Initial releases, email delivery only
- `0.2.0` — Added Paubox Forms API support (public respondent endpoints)
- `0.3.0` — Full Forms API support, including scoped-API-key (authenticated) management endpoints

## Releases

Releases are automated with [release-please](https://github.com/googleapis/release-please). Merging to `master` refreshes a standing release PR; merging *that* PR bumps `lib/paubox_rails/version.rb`, writes `CHANGELOG.md`, creates a bare `vX.Y.Z` tag and a GitHub release, and then **pushes the gem to RubyGems**.

Do **not** hand-edit `VERSION` or add a `CHANGELOG.md` entry — release-please owns both.

The next version comes from PR titles: `feat:` gives a minor bump, `fix:` a patch, and a `!` suffix or a `BREAKING CHANGE:` footer gives a major. `.github/workflows/pr-title.yml` rejects titles release-please cannot parse.

To force a specific version, land an empty commit with a `Release-As` footer. Put the notes in the subject and footers — release-please renders those but not the commit body:

```bash
git commit --allow-empty -m "chore: release 1.0.0" -m "Release-As: 1.0.0"
```

### Publishing

Publishing uses RubyGems **trusted publishing** (OIDC) — no API key is stored. RubyGems pins the trust to the repository and the workflow filename, so **renaming `release-please.yml` breaks publishing** until the trusted publisher entry for the `paubox_rails` gem is updated.

Version numbers on RubyGems are effectively permanent — a yank is only possible within 72 hours and never frees the number for reuse.

### Relationship to the `paubox` gem

This gem depends on `paubox` and the gemspec constraint has to allow whatever major version is current there. When `paubox` takes a major bump, this gem needs a matching release that widens the constraint — otherwise Bundler silently holds users on the older `paubox` with no error. Release `paubox` first, then this gem.
