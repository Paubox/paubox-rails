require 'spec_helper'

RSpec.describe PauboxRails::Webhooks::Client do
  let(:api_key) { 'scoped-test-key' }
  let(:client) { described_class.new(api_key: api_key) }
  let(:endpoint_id) { '2ec66c21-bf48-48eb-8d28-f80b2d6b77c7' }
  let(:http) { instance_double(Net::HTTP) }

  # The repo stubs Net::HTTP itself rather than using WebMock, so every
  # attribute build_http sets has to be declared here or the verifying double
  # rejects the call.
  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  def response_double(code, body)
    instance_double(Net::HTTPResponse, code: code, body: body)
  end

  let(:endpoint_body) do
    {
      'id' => endpoint_id,
      'target_url' => 'https://hooks.example.com/paubox',
      'status' => 'active',
      'events' => ['forms.submission.created'],
      'created_at' => '2026-10-09T01:43:41.639968+00:00',
      'updated_at' => '2026-10-09T01:43:41.639968+00:00'
    }
  end

  describe 'configuration' do
    it 'defaults to the production base URL' do
      expect(described_class.new(api_key: api_key).base_url)
        .to eq('https://api.paubox.com/v1/webhooks')
    end

    it 'accepts a base_url override and trims trailing slashes' do
      c = described_class.new(api_key: api_key, base_url: 'https://api.staging.paubox.net/v1/webhooks/')
      expect(c.base_url).to eq('https://api.staging.paubox.net/v1/webhooks')
    end

    it 'reads the api key from the environment when not passed' do
      allow(ENV).to receive(:fetch).with('PAUBOX_WEBHOOKS_API_KEY', nil).and_return('from-env')
      allow(ENV).to receive(:fetch).with('PAUBOX_WEBHOOKS_URL', nil).and_return(nil)
      expect(described_class.new.api_key).to eq('from-env')
    end

    it 'raises MissingApiKeyError before any request when there is no key' do
      expect(Net::HTTP).not_to receive(:new)
      expect { described_class.new(api_key: nil).list_webhook_endpoints }
        .to raise_error(PauboxRails::Webhooks::MissingApiKeyError, /PAUBOX_WEBHOOKS_API_KEY/)
    end
  end

  describe '#list_webhook_endpoints' do
    let(:list_body) do
      { 'data' => [endpoint_body], 'page_info' => { 'count' => 2, 'items' => 1 } }.to_json
    end

    it 'returns the document with data and page_info' do
      allow(http).to receive(:request).and_return(response_double('200', list_body))

      result = client.list_webhook_endpoints
      expect(result['data'].first['id']).to eq(endpoint_id)
      # count is the total, not the length of this page
      expect(result['page_info']['count']).to eq(2)
      expect(result['data'].length).to eq(1)
    end

    it 'sends a Bearer Authorization header' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('200', list_body) }

      client.list_webhook_endpoints
      expect(request['Authorization']).to eq("Bearer #{api_key}")
    end

    it 'requests the endpoints resource' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('200', list_body) }

      client.list_webhook_endpoints
      expect(request.path).to eq('/v1/webhooks/endpoints')
    end

    it 'appends pagination when given' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('200', list_body) }

      client.list_webhook_endpoints(page: 2, items: 1)
      expect(request.path).to eq('/v1/webhooks/endpoints?page=2&items=1')
    end
  end

  describe '#create_webhook_endpoint' do
    # The service wraps single resources in a "data" envelope and adds a
    # "message" on create. Fixtures that omit it pass against a shape the API
    # never sends.
    let(:created_body) do
      {
        'data' => endpoint_body.merge('signing_secret' => 'whsec_abc123'),
        'message' => 'Store this signing_secret now — it is not shown again.'
      }.to_json
    end

    it 'returns the signing secret on 201' do
      allow(http).to receive(:request).and_return(response_double('201', created_body))

      result = client.create_webhook_endpoint(
        target_url: 'https://hooks.example.com/paubox',
        events: ['forms.submission.created']
      )
      # A bare `true` here, as the Forms client returns for 201, would discard
      # the only copy of the secret the service ever sends.
      expect(result['signing_secret']).to eq('whsec_abc123')
      expect(result['id']).to eq(endpoint_id)
    end

    it 'POSTs target_url and events as JSON' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('201', created_body) }

      client.create_webhook_endpoint(
        target_url: 'https://hooks.example.com/paubox',
        events: ['forms.submission.created']
      )
      expect(request).to be_a(Net::HTTP::Post)
      expect(request['Content-Type']).to eq('application/json')
      expect(JSON.parse(request.body)).to eq(
        'target_url' => 'https://hooks.example.com/paubox',
        'events' => ['forms.submission.created']
      )
    end

    it 'wraps a single event in an array' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('201', created_body) }

      client.create_webhook_endpoint(target_url: 'https://e.test/h', events: 'forms.submission.created')
      expect(JSON.parse(request.body)['events']).to eq(['forms.submission.created'])
    end

    it 'validates locally before sending' do
      expect(http).not_to receive(:request)

      expect { client.create_webhook_endpoint(target_url: '', events: ['x']) }
        .to raise_error(ArgumentError, /target_url/)
      expect { client.create_webhook_endpoint(target_url: 'https://e.test/h', events: []) }
        .to raise_error(ArgumentError, /events/)
    end

    # The catalog belongs to the service and grows without a gem release, so
    # an unrecognised name must reach the server rather than be rejected here.
    it 'does not validate event names' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('201', created_body) }

      client.create_webhook_endpoint(target_url: 'https://e.test/h', events: ['some.future.event'])
      expect(JSON.parse(request.body)['events']).to eq(['some.future.event'])
    end
  end

  describe '#get_webhook_endpoint' do
    it 'unwraps the data envelope and returns the endpoint' do
      allow(http).to receive(:request)
        .and_return(response_double('200', { 'data' => endpoint_body }.to_json))

      result = client.get_webhook_endpoint(endpoint_id)
      expect(result['id']).to eq(endpoint_id)
      expect(result['status']).to eq('active')
    end

    # The secret exists only on the create response.
    it 'does not carry a signing secret' do
      allow(http).to receive(:request)
        .and_return(response_double('200', { 'data' => endpoint_body }.to_json))
      expect(client.get_webhook_endpoint(endpoint_id)).not_to have_key('signing_secret')
    end

    it 'rejects a non-UUID id before any request' do
      expect(Net::HTTP).not_to receive(:new)
      expect { client.get_webhook_endpoint('not-a-uuid') }
        .to raise_error(ArgumentError, /must be a UUID/)
    end

    it 'rejects a path-traversal id before any request' do
      expect(Net::HTTP).not_to receive(:new)
      expect { client.get_webhook_endpoint('../endpoints') }.to raise_error(ArgumentError)
    end

    it 'raises NotFoundError on 404' do
      allow(http).to receive(:request)
        .and_return(response_double('404', { 'message' => 'webhook endpoint not found' }.to_json))
      expect { client.get_webhook_endpoint(endpoint_id) }
        .to raise_error(PauboxRails::Webhooks::NotFoundError)
    end
  end

  describe '#update_webhook_endpoint' do
    let(:disabled_body) { { 'data' => endpoint_body.merge('status' => 'disabled') }.to_json }

    it 'PATCHes only the fields given' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('200', disabled_body) }

      result = client.update_webhook_endpoint(endpoint_id, status: 'disabled')
      expect(request).to be_a(Net::HTTP::Patch)
      expect(JSON.parse(request.body)).to eq('status' => 'disabled')
      expect(result['status']).to eq('disabled')
    end

    it 'sends target_url and events together when both are given' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('200', disabled_body) }

      client.update_webhook_endpoint(endpoint_id, target_url: 'https://new.test/h', events: ['forms.submission.created'])
      expect(JSON.parse(request.body)).to eq(
        'target_url' => 'https://new.test/h',
        'events' => ['forms.submission.created']
      )
    end

    it 'refuses an update with nothing to change' do
      expect(http).not_to receive(:request)
      expect { client.update_webhook_endpoint(endpoint_id) }
        .to raise_error(ArgumentError, /at least one of/)
    end
  end

  describe '#delete_webhook_endpoint' do
    it 'returns true on an empty 204' do
      request = nil
      allow(http).to receive(:request) { |req| request = req; response_double('204', nil) }

      expect(client.delete_webhook_endpoint(endpoint_id)).to be(true)
      expect(request).to be_a(Net::HTTP::Delete)
      expect(request.path).to eq("/v1/webhooks/endpoints/#{endpoint_id}")
    end
  end

  describe 'error mapping' do
    # The service answers {"message": "..."}; the raw body would be a JSON
    # blob in the exception message.
    it 'unwraps the service message on 422' do
      allow(http).to receive(:request)
        .and_return(response_double('422', { 'message' => 'target_url: must be an https URL' }.to_json))

      expect { client.create_webhook_endpoint(target_url: 'http://insecure.test', events: ['x']) }
        .to raise_error(PauboxRails::Webhooks::BadRequestError, 'target_url: must be an https URL')
    end

    it 'maps 403 to ForbiddenError with the event named' do
      allow(http).to receive(:request)
        .and_return(response_double('403', { 'message' => "events: not entitled to 'api_mail_log_delivered'" }.to_json))

      expect { client.list_webhook_endpoints }
        .to raise_error(PauboxRails::Webhooks::ForbiddenError, /not entitled/)
    end

    it 'maps 401 to UnauthorizedError' do
      allow(http).to receive(:request).and_return(response_double('401', ''))
      expect { client.list_webhook_endpoints }
        .to raise_error(PauboxRails::Webhooks::UnauthorizedError)
    end

    # A duplicate target_url comes back as 422, not 409 — mapping keyed on 409
    # would miss it entirely.
    it 'treats a duplicate target_url as a bad request' do
      allow(http).to receive(:request)
        .and_return(response_double('422', { 'message' => 'target_url: an endpoint already exists for this URL' }.to_json))

      expect { client.create_webhook_endpoint(target_url: 'https://e.test/h', events: ['x']) }
        .to raise_error(PauboxRails::Webhooks::BadRequestError, /already exists/)
    end

    it 'falls back to the raw body when the error is not the usual shape' do
      allow(http).to receive(:request).and_return(response_double('422', 'plain text failure'))
      expect { client.list_webhook_endpoints }
        .to raise_error(PauboxRails::Webhooks::BadRequestError, 'plain text failure')
    end

    it 'raises the base Error on an unexpected status' do
      allow(http).to receive(:request).and_return(response_double('500', 'boom'))
      expect { client.list_webhook_endpoints }
        .to raise_error(PauboxRails::Webhooks::Error, /Unexpected response 500/)
    end
  end

  describe 'PauboxRails::Webhooks.client' do
    it 'builds a client' do
      expect(PauboxRails::Webhooks.client(api_key: api_key)).to be_a(described_class)
    end
  end
end
