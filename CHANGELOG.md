# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0](https://github.com/Paubox/paubox-rails/compare/v0.1.6...v1.0.0) (2026-08-21)

First stable release. RubyGems had been on `0.1.6` since September 2021.

### ⚠ BREAKING CHANGES

- Requires `paubox ~> 1.0` ([#17](https://github.com/Paubox/paubox-rails/pull/17)). The previous constraint was `~> 0.3`, which resolves to `< 1.0` and could not pick up [`paubox` 1.0.0](https://rubygems.org/gems/paubox/versions/1.0.0). Applications pinning `paubox` to a 0.x version must upgrade it alongside this gem

### 🚀 New Features

- Add `PauboxRails::Forms::Client` for the Paubox Forms API
  - Public endpoints, no credential attached: `get_form`, `submit_form`
  - Form management with a scoped API key (`forms` scope, read from `PAUBOX_FORMS_API_KEY` or passed to the constructor, sent as a Bearer token): `list_forms`, `create_form`, `get_form_details`, `update_form`, `archive_form`, `unarchive_form`, `copy_form`, `form_stats`
  - Submissions: `list_submissions`, `submissions_csv`, `submission_pdf`
- The Email API no longer requires a username — an API key alone authenticates

### ⚠️ Behavior Changes

- Base URLs move to `api.paubox.com`

### 🔒 Hardening

- Validate and encode caller-supplied values interpolated into Forms request paths. Authenticated endpoints require a UUID; public endpoints encode the segment instead of rejecting it

### 🎉 Enhancements

- Relicense from MIT to Apache 2.0, matching the rest of the Paubox SDKs
- Replace the dead Travis config with a GitHub Actions CI workflow, now covering Ruby 3.1 through 3.4 ([51c3714](https://github.com/Paubox/paubox-rails/commit/51c3714d32bd2ed29c5c07a7a1d073719b58dbec))

## v0.1.6 / 2021-09-27

### 🎉 Enhancements

- Remove the upper bound on the `actionmailer` dependency
- Update the `rake` development dependency

## v0.1.4 / 2019-07-10

### 🎉 Enhancements

- Require `paubox ~> 0.3`

## v0.1.3 / 2018-10-04

### 🎉 Enhancements

- Widen the supported `actionmailer` range

## v0.1.2 / 2018-10-04

### 🎉 Enhancements

- Require `paubox ~> 0.2`

## v0.1.1 / 2018-07-25

### 🎉 Enhancements

- Constrain `actionmailer` to the versions then supported

## v0.1.0 / 2018-04-26

### 🚀 Major Release

First release of the Paubox Transactional Email adapter for ActionMailer.
