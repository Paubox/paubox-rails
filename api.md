# Paubox API Reference

This document covers the API endpoints exposed by `paubox-rails`. The gem wraps two separate Paubox services:

- **Email API** — authenticated, delegates to the [`paubox`](https://github.com/paubox/paubox_ruby) gem via ActionMailer
- **Forms API** — public (no authentication), implemented directly in this gem

---

## Forms API

**Base URL:** `https://next.paubox.com`

No authentication is required for any Forms endpoint. These endpoints are called on behalf of form respondents, not server-side API consumers.

---

### GET `/public/form_data/{form_id}` — Get form metadata

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

## Email API

Email delivery is handled transparently by ActionMailer using the `:paubox` delivery method. There is no direct HTTP interaction in this gem — all email API calls are delegated to the [`paubox`](https://github.com/paubox/paubox_ruby) gem.

See the [Paubox Ruby gem documentation](https://github.com/paubox/paubox_ruby) for the full Email API reference, including message status tracking and templated messages.
