require 'spec_helper'

RSpec.describe PauboxRails::Forms::Client do
  let(:client) { described_class.new }
  let(:form_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
  end

  describe '#get_form' do
    let(:form_body) do
      {
        'id' => form_id,
        'title' => 'Patient Intake Form',
        'description' => 'Please complete before your appointment.',
        'form_json' => {},
        'form_html' => '<form>...</form>',
        'form_css' => 'form { font-family: sans-serif; }',
        'active' => true,
        'customer_id' => 123,
        'signable' => false,
        'submission_count' => 42,
        'created_at' => '2024-01-15T10:30:00Z',
        'updated_at' => '2024-06-01T08:00:00Z'
      }.to_json
    end

    it 'returns parsed form hash on 200' do
      response = instance_double(Net::HTTPResponse, code: '200', body: form_body)
      allow(http).to receive(:get).and_return(response)

      result = client.get_form(form_id)
      expect(result['title']).to eq('Patient Intake Form')
      expect(result['submission_count']).to eq(42)
    end

    it 'raises NotFoundError on 404' do
      response = instance_double(Net::HTTPResponse, code: '404', body: '')
      allow(http).to receive(:get).and_return(response)

      expect { client.get_form(form_id) }
        .to raise_error(PauboxRails::Forms::NotFoundError, 'Form not found')
    end
  end

  describe '#submit_form' do
    it 'returns true on 201' do
      response = instance_double(Net::HTTPResponse, code: '201', body: '')
      allow(http).to receive(:request).and_return(response)

      result = client.submit_form(form_id, form_data: { first_name: 'Jane', email: 'jane@example.com' })
      expect(result).to be true
    end

    it 'raises BadRequestError on 400' do
      response = instance_double(Net::HTTPResponse, code: '400', body: '{"error":"Missing form_data"}')
      allow(http).to receive(:request).and_return(response)

      expect { client.submit_form(form_id, form_data: {}) }
        .to raise_error(PauboxRails::Forms::BadRequestError)
    end

    it 'raises NotFoundError on 404' do
      response = instance_double(Net::HTTPResponse, code: '404', body: '')
      allow(http).to receive(:request).and_return(response)

      expect { client.submit_form(form_id, form_data: { name: 'Jane' }) }
        .to raise_error(PauboxRails::Forms::NotFoundError, 'Form not found')
    end

    it 'includes attachments in the payload when provided' do
      response = instance_double(Net::HTTPResponse, code: '201', body: '')
      allow(http).to receive(:request) do |req|
        payload = JSON.parse(req.body)
        expect(payload['attachments']).to eq([{ 'name' => 'consent.pdf', 'content' => 'JVBERi0xLjQ=' }])
        response
      end

      client.submit_form(
        form_id,
        form_data: { name: 'Jane' },
        attachments: [{ name: 'consent.pdf', content: 'JVBERi0xLjQ=' }]
      )
    end

    it 'omits attachments key when not provided' do
      response = instance_double(Net::HTTPResponse, code: '201', body: '')
      allow(http).to receive(:request) do |req|
        payload = JSON.parse(req.body)
        expect(payload).not_to have_key('attachments')
        response
      end

      client.submit_form(form_id, form_data: { name: 'Jane' })
    end
  end

  describe 'protected endpoints' do
    let(:api_key) { 'sk-test-key' }
    let(:auth_client) { described_class.new(api_key: api_key) }

    describe 'authentication' do
      PROTECTED_CALLS = {
        list_forms: ->(c) { c.list_forms(customer_id: 1) },
        create_form: ->(c) { c.create_form(title: 'T', form_json: {}, customer_id: 1, version: 1) },
        get_form_details: ->(c) { c.get_form_details('abc') },
        update_form: ->(c) { c.update_form('abc', title: 'T') },
        archive_form: ->(c) { c.archive_form('abc') },
        unarchive_form: ->(c) { c.unarchive_form('abc') },
        copy_form: ->(c) { c.copy_form('abc', title: 'Copy') },
        form_stats: ->(c) { c.form_stats },
        list_submissions: ->(c) { c.list_submissions('abc') },
        submissions_csv: ->(c) { c.submissions_csv('abc') },
        submission_pdf: ->(c) { c.submission_pdf('abc', 'sub-1') }
      }.freeze

      context 'when the client has no api_key' do
        let(:no_key_client) { described_class.new(api_key: nil) }

        PROTECTED_CALLS.each do |name, call|
          it "raises MissingApiKeyError from ##{name} without making any HTTP call" do
            expect { call.call(no_key_client) }
              .to raise_error(PauboxRails::Forms::MissingApiKeyError, /requires an API key/)
            expect(Net::HTTP).not_to have_received(:new)
          end
        end
      end

      it 'sends Authorization: Bearer <key> on authenticated GET requests' do
        response = instance_double(Net::HTTPResponse, code: '200', body: '{"data":{}}')
        allow(http).to receive(:request) do |req|
          expect(req['Authorization']).to eq("Bearer #{api_key}")
          response
        end

        auth_client.get_form_details(form_id)
      end

      it 'sends Authorization: Bearer <key> on authenticated POST requests' do
        response = instance_double(Net::HTTPResponse, code: '200', body: '{"detail":"Form archived."}')
        allow(http).to receive(:request) do |req|
          expect(req['Authorization']).to eq("Bearer #{api_key}")
          response
        end

        auth_client.archive_form(form_id)
      end
    end

    describe '#list_forms' do
      let(:list_body) do
        {
          'results' => [{ 'id' => form_id, 'title' => 'Patient Intake Form' }],
          'page_info' => { 'count' => 1, 'pages' => 1, 'page' => 1, 'items' => 50 }
        }.to_json
      end

      it 'returns the parsed results and page_info on 200' do
        response = instance_double(Net::HTTPResponse, code: '200', body: list_body)
        allow(http).to receive(:request).and_return(response)

        result = auth_client.list_forms(customer_id: 123)
        expect(result['results'].first['title']).to eq('Patient Intake Form')
        expect(result['page_info']['count']).to eq(1)
      end

      it 'includes only provided params in the query string' do
        response = instance_double(Net::HTTPResponse, code: '200', body: list_body)
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq('/forms/api/forms?customer_id=123&archived=false&page=2')
          response
        end

        auth_client.list_forms(customer_id: 123, archived: false, page: 2)
      end

      it 'requires customer_id (the API rejects listing without one with 403)' do
        expect { auth_client.list_forms }.to raise_error(ArgumentError, /customer_id/)
        expect(Net::HTTP).not_to have_received(:new)
      end

      it 'raises UnauthorizedError on 401' do
        response = instance_double(Net::HTTPResponse, code: '401', body: '{"error":"invalid key"}')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.list_forms(customer_id: 123) }
          .to raise_error(PauboxRails::Forms::UnauthorizedError, /Unauthorized/)
      end

      it 'raises ForbiddenError on 403 when the key cannot access the customer' do
        response = instance_double(Net::HTTPResponse, code: '403', body: '{"message":"Forbidden"}')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.list_forms(customer_id: 999) }
          .to raise_error(PauboxRails::Forms::ForbiddenError, /Forbidden/)
      end
    end

    describe '#create_form' do
      let(:created_body) { { 'id' => form_id }.to_json }

      it 'returns the parsed id hash on 200' do
        response = instance_double(Net::HTTPResponse, code: '200', body: created_body)
        allow(http).to receive(:request).and_return(response)

        result = auth_client.create_form(title: 'Intake', form_json: { 'fields' => [] },
                                         customer_id: 123, version: 2)
        expect(result).to eq('id' => form_id)
      end

      it 'sends required fields, emits "type", keeps false values, and drops nil optionals' do
        response = instance_double(Net::HTTPResponse, code: '200', body: created_body)
        allow(http).to receive(:request) do |req|
          expect(req).to be_a(Net::HTTP::Post)
          expect(req.path).to eq('/forms/api/forms')
          payload = JSON.parse(req.body)
          expect(payload).to include(
            'title' => 'Intake',
            'form_json' => { 'fields' => [] },
            'customer_id' => 123,
            'version' => 2,
            'type' => 'intake',
            'active' => false
          )
          expect(payload).not_to have_key('description')
          expect(payload).not_to have_key('form_html')
          response
        end

        auth_client.create_form(title: 'Intake', form_json: { 'fields' => [] },
                                customer_id: 123, version: 2, type: 'intake', active: false)
      end

      it 'raises BadRequestError on 400' do
        response = instance_double(Net::HTTPResponse, code: '400', body: '{"error":"title taken"}')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.create_form(title: 'Intake', form_json: {}, customer_id: 1, version: 1) }
          .to raise_error(PauboxRails::Forms::BadRequestError, /Bad request/)
      end

      it 'raises BadRequestError on 422 (body failed server-side validation)' do
        response = instance_double(Net::HTTPResponse, code: '422',
                                   body: 'Failed to deserialize the JSON body into the target type')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.create_form(title: 'Intake', form_json: {}, customer_id: 1, version: 1) }
          .to raise_error(PauboxRails::Forms::BadRequestError, /Bad request/)
      end
    end

    describe '#get_form_details' do
      it 'returns the parsed data envelope on 200' do
        body = { 'data' => { 'id' => form_id, 'title' => 'Patient Intake Form' } }.to_json
        response = instance_double(Net::HTTPResponse, code: '200', body: body)
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq("/forms/api/forms/#{form_id}")
          response
        end

        result = auth_client.get_form_details(form_id)
        expect(result['data']['title']).to eq('Patient Intake Form')
      end

      it 'raises the generic Error on 500 (the API returns 500, not 404, for a missing form)' do
        response = instance_double(Net::HTTPResponse, code: '500',
                                   body: 'no rows returned by a query that expected to return at least one row')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.get_form_details(form_id) }
          .to raise_error(PauboxRails::Forms::Error, /Unexpected response 500/)
      end
    end

    describe '#update_form' do
      let(:updated_body) { { 'detail' => 'Form updated successfully', 'form_id' => form_id }.to_json }

      it 'returns the parsed confirmation on 200' do
        response = instance_double(Net::HTTPResponse, code: '200', body: updated_body)
        allow(http).to receive(:request).and_return(response)

        result = auth_client.update_form(form_id, title: 'Renamed')
        expect(result['detail']).to eq('Form updated successfully')
      end

      it 'PUTs a body containing only caller-provided keys' do
        response = instance_double(Net::HTTPResponse, code: '200', body: updated_body)
        allow(http).to receive(:request) do |req|
          expect(req).to be_a(Net::HTTP::Put)
          expect(req.path).to eq("/forms/api/forms/#{form_id}")
          payload = JSON.parse(req.body)
          expect(payload.keys).to contain_exactly('title', 'active')
          expect(payload['title']).to eq('Renamed')
          expect(payload['active']).to be false
          response
        end

        auth_client.update_form(form_id, title: 'Renamed', active: false)
      end

      it 'drops nil values (the server treats null as "leave unchanged") and unknown keys' do
        response = instance_double(Net::HTTPResponse, code: '200', body: updated_body)
        allow(http).to receive(:request) do |req|
          payload = JSON.parse(req.body)
          expect(payload.keys).to contain_exactly('title')
          response
        end

        auth_client.update_form(form_id, title: 'Renamed', description: nil, bogus_key: 'ignored')
      end

      it 'raises NotFoundError on 404' do
        response = instance_double(Net::HTTPResponse, code: '404', body: '')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.update_form(form_id, title: 'Renamed') }
          .to raise_error(PauboxRails::Forms::NotFoundError, 'Form not found')
      end
    end

    describe '#archive_form' do
      it 'POSTs to the archive path with no body and returns the parsed detail' do
        body = { 'detail' => 'Form archived.' }.to_json
        response = instance_double(Net::HTTPResponse, code: '200', body: body)
        allow(http).to receive(:request) do |req|
          expect(req).to be_a(Net::HTTP::Post)
          expect(req.path).to eq("/forms/api/forms/#{form_id}/archive")
          expect(req.body).to be_nil
          expect(req['Content-Type']).to be_nil
          response
        end

        expect(auth_client.archive_form(form_id)).to eq('detail' => 'Form archived.')
      end

      it "raises ForbiddenError on 403 (the key's customer cannot access the form)" do
        response = instance_double(Net::HTTPResponse, code: '403', body: '{"message":"Forbidden"}')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.archive_form(form_id) }
          .to raise_error(PauboxRails::Forms::ForbiddenError, /Forbidden/)
      end
    end

    describe '#unarchive_form' do
      it 'POSTs to the unarchive path and returns the parsed detail' do
        body = { 'detail' => 'Form unarchived.' }.to_json
        response = instance_double(Net::HTTPResponse, code: '200', body: body)
        allow(http).to receive(:request) do |req|
          expect(req).to be_a(Net::HTTP::Post)
          expect(req.path).to eq("/forms/api/forms/#{form_id}/unarchive")
          expect(req.body).to be_nil
          response
        end

        expect(auth_client.unarchive_form(form_id)).to eq('detail' => 'Form unarchived.')
      end

      it 'raises UnauthorizedError on 401 (missing/invalid key or key without the forms scope)' do
        response = instance_double(Net::HTTPResponse, code: '401', body: '')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.unarchive_form(form_id) }
          .to raise_error(PauboxRails::Forms::UnauthorizedError)
      end
    end

    describe '#copy_form' do
      it 'POSTs form_id and title to /api/forms/copy and returns the new form' do
        body = { 'id' => 'new-form-uuid', 'title' => 'Intake (Copy)' }.to_json
        response = instance_double(Net::HTTPResponse, code: '200', body: body)
        allow(http).to receive(:request) do |req|
          expect(req).to be_a(Net::HTTP::Post)
          expect(req.path).to eq('/forms/api/forms/copy')
          payload = JSON.parse(req.body)
          expect(payload).to eq('form_id' => form_id, 'title' => 'Intake (Copy)')
          response
        end

        result = auth_client.copy_form(form_id, title: 'Intake (Copy)')
        expect(result['id']).to eq('new-form-uuid')
      end

      it 'raises NotFoundError on 404 when the source form is missing' do
        response = instance_double(Net::HTTPResponse, code: '404', body: '')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.copy_form(form_id, title: 'Copy') }
          .to raise_error(PauboxRails::Forms::NotFoundError)
      end
    end

    describe '#form_stats' do
      let(:stats_body) do
        { 'active_form_count' => 5, 'total_submission_count' => 120, 'submissions_last_7_days' => 8 }.to_json
      end

      it 'returns parsed stats and requests the bare stats path without customer_id' do
        response = instance_double(Net::HTTPResponse, code: '200', body: stats_body)
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq('/forms/api/forms/stats')
          response
        end

        result = auth_client.form_stats
        expect(result['active_form_count']).to eq(5)
      end

      it 'includes customer_id in the query string when given' do
        response = instance_double(Net::HTTPResponse, code: '200', body: stats_body)
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq('/forms/api/forms/stats?customer_id=42')
          response
        end

        auth_client.form_stats(customer_id: 42)
      end

      it 'raises UnauthorizedError on 401' do
        response = instance_double(Net::HTTPResponse, code: '401', body: '')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.form_stats }
          .to raise_error(PauboxRails::Forms::UnauthorizedError)
      end
    end

    describe '#list_submissions' do
      let(:submissions_body) do
        {
          'data' => [{ 'id' => 'sub-1', 'submitter_email' => 'jane@example.com' }],
          'total' => 1, 'page' => 1, 'items' => 50
        }.to_json
      end

      it 'returns the parsed submissions payload on 200' do
        response = instance_double(Net::HTTPResponse, code: '200', body: submissions_body)
        allow(http).to receive(:request).and_return(response)

        result = auth_client.list_submissions(form_id)
        expect(result['data'].first['id']).to eq('sub-1')
        expect(result['total']).to eq(1)
      end

      it 'includes only provided params in the query string' do
        response = instance_double(Net::HTTPResponse, code: '200', body: submissions_body)
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq("/forms/api/forms/#{form_id}/submissions?page=3&order=asc")
          response
        end

        auth_client.list_submissions(form_id, page: 3, order: 'asc')
      end

      it 'raises NotFoundError on 404 when the form is missing' do
        response = instance_double(Net::HTTPResponse, code: '404', body: '')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.list_submissions(form_id) }
          .to raise_error(PauboxRails::Forms::NotFoundError)
      end
    end

    describe '#submissions_csv' do
      let(:csv_body) { "id,submitter_email\nsub-1,jane@example.com\n" }

      it 'returns the raw CSV body untouched' do
        response = instance_double(Net::HTTPResponse, code: '200', body: csv_body)
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq("/forms/api/forms/#{form_id}/submissions/submission-csv")
          response
        end

        expect(auth_client.submissions_csv(form_id)).to eq(csv_body)
      end

      it 'appends the submission_id to the path for a single submission' do
        response = instance_double(Net::HTTPResponse, code: '200', body: csv_body)
        allow(http).to receive(:request) do |req|
          expect(req.path).to eq("/forms/api/forms/#{form_id}/submissions/submission-csv/sub-1")
          response
        end

        expect(auth_client.submissions_csv(form_id, submission_id: 'sub-1')).to eq(csv_body)
      end

      it 'raises NotFoundError on 404' do
        response = instance_double(Net::HTTPResponse, code: '404', body: '')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.submissions_csv(form_id) }
          .to raise_error(PauboxRails::Forms::NotFoundError)
      end
    end

    describe '#submission_pdf' do
      let(:pdf_body) { "%PDF-1.4\x00\x01binary-content".dup.force_encoding(Encoding::BINARY) }

      it 'returns the raw binary body untouched' do
        response = instance_double(Net::HTTPResponse, code: '200', body: pdf_body)
        allow(http).to receive(:request) do |req|
          expect(req.path)
            .to eq("/forms/api/forms/#{form_id}/submissions/sub-1/submission-pdf")
          response
        end

        expect(auth_client.submission_pdf(form_id, 'sub-1')).to eq(pdf_body)
      end

      it 'raises the generic Error on 500 (the API returns 500, not 404, for a missing form or submission)' do
        response = instance_double(Net::HTTPResponse, code: '500',
                                   body: 'no rows returned by a query that expected to return at least one row')
        allow(http).to receive(:request).and_return(response)

        expect { auth_client.submission_pdf(form_id, 'sub-1') }
          .to raise_error(PauboxRails::Forms::Error, /Unexpected response 500/)
      end
    end
  end

  describe 'api_key resolution' do
    it 'falls back to ENV["PAUBOX_FORMS_API_KEY"] when no api_key is passed' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('PAUBOX_FORMS_API_KEY', nil).and_return('env-key')

      expect(described_class.new.api_key).to eq('env-key')
    end

    it 'has a nil api_key when neither argument nor ENV variable is set' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('PAUBOX_FORMS_API_KEY', nil).and_return(nil)

      expect(described_class.new.api_key).to be_nil
    end

    it 'prefers an explicitly passed api_key over the ENV variable' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('PAUBOX_FORMS_API_KEY', nil).and_return('env-key')

      expect(described_class.new(api_key: 'explicit-key').api_key).to eq('explicit-key')
    end
  end
end

RSpec.describe PauboxRails::Forms do
  describe '.client' do
    it 'passes api_key through to the Client' do
      client = described_class.client(api_key: 'factory-key')
      expect(client).to be_a(PauboxRails::Forms::Client)
      expect(client.api_key).to eq('factory-key')
    end

    it 'applies the ENV fallback when called without an api_key' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('PAUBOX_FORMS_API_KEY', nil).and_return('env-key')

      expect(described_class.client.api_key).to eq('env-key')
    end
  end
end
