# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

Not yet on RubyGems. The newest published version is still `0.1.6` from September 2021.

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
- Replace the dead Travis config with a GitHub Actions CI workflow

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
