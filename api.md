# Paubox API Reference

This document covers the API endpoints exposed by `paubox-rails`. The gem wraps two separate Paubox services:

- **Email API** — authenticated, delegates to the [`paubox`](https://github.com/paubox/paubox_ruby) gem via ActionMailer
- **Forms API** — public respondent endpoints plus authenticated management endpoints, implemented directly in this gem

---

## Forms API

**Base URL:** `https://api.paubox.com/forms`

### Authentication

Forms endpoints fall into two groups:

- **Public endpoints** — called on behalf of form respondents (fetching a form definition, submitting a response). No authentication is required.
- **Protected endpoints** — form management, statistics, and submission retrieval. These require a **scoped Paubox API key** carrying the `forms` scope, sent as a Bearer token:

  ```
  Authorization: Bearer <api_key>
  ```

Generate a scoped API key from your Paubox dashboard and grant it the `forms` scope. In Ruby, pass the key when building the client:

```ruby
client = PauboxRails::Forms.client(api_key: ENV['PAUBOX_FORMS_API_KEY'])
```

Alternatively, `PauboxRails::Forms::Client.new` reads the `PAUBOX_FORMS_API_KEY` environment variable by default:

```ruby
client = PauboxRails::Forms::Client.new # api_key defaults to ENV['PAUBOX_FORMS_API_KEY']
```

The `PauboxRails::Forms.client` factory applies the same fallback when called without an `api_key:`.

Calling a protected method on a client with no API key raises `PauboxRails::Forms::MissingApiKeyError` before any HTTP request is made.

**Authentication error responses** (all protected endpoints)

| Status | Meaning | Ruby exception |
|--------|---------|----------------|
| 401    | Missing or invalid API key, **or** a key without the `forms` scope | `PauboxRails::Forms::UnauthorizedError` |
| 403    | The key is valid, but its customer does not have access to the target form or customer | `PauboxRails::Forms::ForbiddenError` |

Note that a key lacking the `forms` scope is rejected by the authentication layer with **401**, not 403. A 403 always means an ownership/access problem: the authenticated customer neither owns the resource nor has a relationship with the customer that does.

---

### GET `/public/form_data/{form_id}` — Get form metadata

**Public — no authentication required.**

Returns the full form definition for embedding and rendering.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form to retrieve |

**Response — 200 OK**

```json
{
  "id":                          "550e8400-e29b-41d4-a716-446655440000",
  "title":                       "Patient Intake Form",
  "description":                 "Please complete before your appointment.",
  "form_json":                   {},
  "form_html":                   "<form>...</form>",
  "form_css":                    "form { font-family: sans-serif; }",
  "vanity_url":                  null,
  "version":                     1,
  "active":                      true,
  "customer_id":                 123,
  "signable":                    false,
  "signature_confirmation_label": null,
  "submission_count":            42,
  "type":                        null,
  "deleted":                     false,
  "archived":                    false,
  "created_at":                  "2024-01-15T10:30:00Z",
  "updated_at":                  "2024-06-01T08:00:00Z"
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 404    | Form not found |

**Ruby usage**

```ruby
client = PauboxRails::Forms.client
form = client.get_form('550e8400-e29b-41d4-a716-446655440000')
```

---

### POST `/api/forms/{form_id}/submissions` — Submit a form response

**Public — no authentication required.**

Stores a respondent's answers, increments the submission count, and emails recipients (if configured). Returns 201 with no body on success.

Maximum request size: **250 MB** (to support file attachments).

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form being submitted |

**Request body** (`application/json`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `form_data` | object | Yes | Key-value pairs matching the form's field schema |
| `attachments` | array | No | Optional file attachments (see below) |

**Attachment object**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Filename (e.g. `"consent.pdf"`) |
| `content` | string | Yes | Base64-encoded file content |

**Example — text fields only**

```json
{
  "form_data": {
    "first_name": "Jane",
    "last_name":  "Smith",
    "email":      "jane@example.com"
  }
}
```

**Example — with file attachment**

```json
{
  "form_data": {
    "first_name": "Jane"
  },
  "attachments": [
    {
      "name":    "consent.pdf",
      "content": "JVBERi0xLjQ..."
    }
  ]
}
```

**Response — 201 Created** (no body)

**Error responses**

| Status | Meaning |
|--------|---------|
| 400    | Missing required `form_data` field |
| 404    | Form not found |

**Ruby usage**

```ruby
client = PauboxRails::Forms.client

# Simple submission
client.submit_form(form_id, form_data: { first_name: 'Jane', email: 'jane@example.com' })

# With attachment
require 'base64'
client.submit_form(
  form_id,
  form_data:   { first_name: 'Jane' },
  attachments: [{ name: 'consent.pdf', content: Base64.strict_encode64(File.read('consent.pdf')) }]
)
```

---

### GET `/api/forms` — List forms

**Protected — requires API key.**

Returns a paginated list of forms for a customer.

**Query parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `customer_id` | integer | Yes | Customer whose forms to list. Must be the API key's own customer, or a customer related to it. The server authorizes the request against this value — omitting it is always rejected with 403 for API-key callers, so the Ruby client requires it. |
| `form_id` | UUID string | No | Filter to a single form |
| `search` | string | No | Search term matched against form titles **or descriptions** |
| `order` | string | No | `asc` or `desc` (default `desc`) |
| `order_by` | string | No | `title`, `updated_at`, `submission_count`, or `created_at` |
| `archived` | boolean | No | Filter by archived state |
| `active` | boolean | No | Filter by active state |
| `page` | integer | No | Page number (default 1) |
| `items` | integer | No | Items per page (default 50, capped at 100 by the server) |

Only parameters you pass are included in the request.

**Response — 200 OK**

```json
{
  "results": [
    {
      "id":    "550e8400-e29b-41d4-a716-446655440000",
      "title": "Patient Intake Form",
      "...":   "..."
    }
  ],
  "page_info": {
    "count": 12,
    "pages": 1,
    "page":  1,
    "items": 50
  }
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 400    | Invalid query parameter |
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | `customer_id` omitted, or the key's customer cannot access the requested customer |

**Ruby usage**

```ruby
client = PauboxRails::Forms.client(api_key: ENV['PAUBOX_FORMS_API_KEY'])

client.list_forms(customer_id: 123)
client.list_forms(customer_id: 123, search: 'intake', order_by: 'updated_at', order: 'desc')
client.list_forms(customer_id: 123, active: true, page: 2, items: 25)
```

---

### POST `/api/forms` — Create a form

**Protected — requires API key.**

Creates a new form and returns its UUID.

**Request body** (`application/json`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Form title |
| `form_json` | object | Yes | Form field schema |
| `customer_id` | integer | Yes | Customer the form belongs to |
| `version` | integer | Yes | Form schema version |
| `description` | string | No | Form description |
| `form_html` | string | No | Rendered form HTML |
| `form_css` | string | No | Form stylesheet |
| `recipient` | string | No | Email address notified on submission |
| `signable` | boolean | No | Whether the form supports signatures |
| `signature_confirmation_label` | string | No | Label shown next to the signature confirmation |
| `subscription_list_id` | string | No | Subscription list to add respondents to |
| `type` | string | No | Form type |
| `active` | boolean | No | Whether the form is active |
| `submission_count` | integer | No | Initial submission count |

Optional fields you don't pass are omitted from the request body (`false` values are kept).

**Response — 200 OK**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 400    | Malformed JSON body |
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access the target `customer_id` |
| 422    | Missing or mistyped required field (body fails validation) |

Both 400 and 422 raise `PauboxRails::Forms::BadRequestError` in Ruby.

**Ruby usage**

```ruby
result = client.create_form(
  title:       'Patient Intake Form',
  form_json:   { fields: [{ name: 'first_name', type: 'text' }] },
  customer_id: 123,
  version:     1,
  description: 'Please complete before your appointment.',
  recipient:   'intake@clinic.example.com'
)
result['id'] # => "550e8400-e29b-41d4-a716-446655440000"
```

---

### GET `/api/forms/{form_id}` — Get form details

**Protected — requires API key.**

Returns the full form record. Unlike the public `get_form`, this endpoint is authenticated and wraps the form in a `data` key.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form to retrieve |

**Response — 200 OK**

```json
{
  "data": {
    "id":    "550e8400-e29b-41d4-a716-446655440000",
    "title": "Patient Intake Form",
    "...":   "..."
  }
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access this form |
| 500    | Form not found (the API currently returns 500, not 404, for a missing form — raises the generic `PauboxRails::Forms::Error`) |

**Ruby usage**

```ruby
details = client.get_form_details('550e8400-e29b-41d4-a716-446655440000')
details['data']['title'] # => "Patient Intake Form"
```

---

### PUT `/api/forms/{form_id}` — Update a form

**Protected — requires API key.**

PATCH-style update: only the attributes you pass are sent in the request body, so unmentioned attributes are left unchanged. The server treats a JSON `null` exactly like an omitted key ("leave unchanged"), so **fields cannot be cleared via this endpoint** — the Ruby client drops `nil` values from the payload rather than sending a `null` that would do nothing.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form to update |

**Request body** (`application/json`) — all fields optional

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Form title |
| `description` | string | Form description |
| `form_json` | object | Form field schema |
| `vanity_url` | string | Custom URL slug |
| `recipient` | string | Email address notified on submission |
| `active` | boolean | Whether the form is active |
| `subscription_list_id` | string | Subscription list to add respondents to |

Keys outside this list, and keys with `nil` values, are silently dropped by the client.

**Response — 200 OK**

```json
{
  "detail":  "Form updated successfully",
  "form_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access this form |
| 404    | Form not found |
| 422    | Mistyped attribute value (body fails validation; raises `BadRequestError` in Ruby) |

**Ruby usage**

```ruby
client.update_form(form_id, title: 'Updated Intake Form', active: false)
```

---

### POST `/api/forms/{form_id}/archive` — Archive a form

**Protected — requires API key.**

Archives the form. The request has no body.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form to archive |

**Response — 200 OK**

```json
{
  "detail": "Form archived."
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access this form |

Note: archiving a nonexistent form id is **not** an error — the server runs an unconditional update and still responds 200 `{"detail": "Form archived."}`.

**Ruby usage**

```ruby
client.archive_form(form_id)
```

---

### POST `/api/forms/{form_id}/unarchive` — Unarchive a form

**Protected — requires API key.**

Restores an archived form. The request has no body.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form to unarchive |

**Response — 200 OK**

```json
{
  "detail": "Form unarchived."
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access this form |

Note: unarchiving a nonexistent form id is **not** an error — the server runs an unconditional update and still responds 200 `{"detail": "Form unarchived."}`.

**Ruby usage**

```ruby
client.unarchive_form(form_id)
```

---

### POST `/api/forms/copy` — Copy a form

**Protected — requires API key.**

Duplicates an existing form under a new title and returns the full new form.

**Request body** (`application/json`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form to copy |
| `title` | string | Yes | Title for the new copy |

**Response — 200 OK** — the full new form object

```json
{
  "id":    "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "title": "Patient Intake Form (Copy)",
  "...":   "..."
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access the source form |
| 404    | Source form not found |
| 422    | Missing `form_id` or `title` (body fails validation; raises `BadRequestError` in Ruby) |

**Ruby usage**

```ruby
new_form = client.copy_form(form_id, title: 'Patient Intake Form (Copy)')
new_form['id'] # => UUID of the copy
```

---

### GET `/api/forms/stats` — Form statistics

**Protected — requires API key.**

Returns aggregate form statistics. Defaults to the API key's customer when `customer_id` is not given.

**Query parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `customer_id` | integer | No | Customer to report on (defaults to the key's customer) |

**Response — 200 OK**

```json
{
  "active_form_count":        8,
  "total_submission_count":   1250,
  "submissions_last_7_days":  37
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access the requested customer |

**Ruby usage**

```ruby
stats = client.form_stats
stats['active_form_count'] # => 8
```

---

### GET `/api/forms/{form_id}/submissions` — List submissions

**Protected — requires API key.**

Returns a paginated list of submissions for a form.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form |

**Query parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `page` | integer | No | Page number |
| `items` | integer | No | Items per page (capped at 100 by the server) |
| `order` | string | No | `asc` or `desc` |
| `order_by` | string | No | `submitter_email` or `created_at` |
| `submission_id` | UUID string | No | Filter to a single submission |

Only parameters you pass are included in the request.

**Response — 200 OK**

```json
{
  "data": [
    {
      "id":              "9b2f1c3a-1111-2222-3333-444455556666",
      "submitter_email": "jane@example.com",
      "form_data":       {},
      "created_at":      "2024-06-01T08:00:00Z"
    }
  ],
  "total": 42,
  "page":  1,
  "items": 50
}
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access this form |
| 404    | Form not found |

**Ruby usage**

```ruby
client.list_submissions(form_id)
client.list_submissions(form_id, page: 2, items: 25, order_by: 'created_at', order: 'asc')
```

---

### GET `/api/forms/{form_id}/submissions/submission-csv` — Export submissions as CSV

**Protected — requires API key.**

Exports all submissions for a form (or a single submission) as CSV. The response is `text/csv`, so the client returns the **raw response body string** — it is not JSON-parsed.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form |
| `submission_id` | UUID string | No | Appended as `/submission-csv/{submission_id}` to export a single submission |

**Response — 200 OK** (`text/csv`)

```csv
first_name,last_name,email,created_at
Jane,Smith,jane@example.com,2024-06-01T08:00:00Z
```

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access this form |
| 404    | Form not found |

**Ruby usage**

```ruby
csv = client.submissions_csv(form_id)                                  # all submissions
csv = client.submissions_csv(form_id, submission_id: submission_id)   # single submission
File.write('submissions.csv', csv)
```

---

### GET `/api/forms/{form_id}/submissions/{submission_id}/submission-pdf` — Download a submission as PDF

**Protected — requires API key.**

Renders a single submission as a PDF. The response is `application/pdf`, so the client returns the **raw binary body string** — it is not JSON-parsed.

**Path parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `form_id` | UUID string | Yes | UUID of the form |
| `submission_id` | UUID string | Yes | UUID of the submission |

**Response — 200 OK** (`application/pdf`, binary body)

**Error responses**

| Status | Meaning |
|--------|---------|
| 401    | Missing or invalid API key, or key without the `forms` scope |
| 403    | The key's customer cannot access this form |
| 500    | Form or submission not found (the API currently returns 500, not 404, for a missing record — raises the generic `PauboxRails::Forms::Error`) |

**Ruby usage**

```ruby
pdf = client.submission_pdf(form_id, submission_id)
File.binwrite('submission.pdf', pdf)
```

---

## Email API

Email delivery is handled transparently by ActionMailer using the `:paubox` delivery method. There is no direct HTTP interaction in this gem — all email API calls are delegated to the [`paubox`](https://github.com/paubox/paubox_ruby) gem.

See the [Paubox Ruby gem documentation](https://github.com/paubox/paubox_ruby) for the full Email API reference, including message status tracking and templated messages.
