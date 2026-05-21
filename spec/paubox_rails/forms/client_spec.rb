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
end
