require 'net/http'
require 'json'
require 'uri'

module PauboxRails
  module Forms
    class Client
      UPDATABLE_FORM_KEYS = %i[title description form_json vanity_url recipient active subscription_list_id].freeze

      attr_reader :api_key

      def initialize(api_key: ENV.fetch('PAUBOX_FORMS_API_KEY', nil))
        @api_key = api_key
      end

      def get_form(form_id)
        uri = URI.parse("#{BASE_URL}/public/form_data/#{form_id}")
        http = build_http(uri)
        response = http.get(uri.path)
        handle_response(response)
      end

      def submit_form(form_id, form_data:, attachments: nil)
        uri = URI.parse("#{BASE_URL}/api/forms/#{form_id}/submissions")
        http = build_http(uri)

        payload = { form_data: form_data }
        payload[:attachments] = attachments if attachments

        request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
        request.body = payload.to_json

        response = http.request(request)
        handle_response(response)
      end

      # customer_id is required: the Forms API authorizes list requests by comparing
      # the provided customer_id against the API key's customer (or a related
      # customer), and rejects requests without one with 403 Forbidden.
      def list_forms(customer_id:, form_id: nil, search: nil, order: nil, order_by: nil,
                     archived: nil, active: nil, page: nil, items: nil)
        query = build_query(customer_id: customer_id, form_id: form_id, search: search,
                            order: order, order_by: order_by, archived: archived,
                            active: active, page: page, items: items)
        authenticated_get("/api/forms#{query}")
      end

      def create_form(title:, form_json:, customer_id:, version:, description: nil,
                      form_html: nil, form_css: nil, recipient: nil, signable: nil,
                      signature_confirmation_label: nil, subscription_list_id: nil,
                      type: nil, active: nil, submission_count: nil)
        payload = {
          title: title,
          form_json: form_json,
          customer_id: customer_id,
          version: version,
          description: description,
          form_html: form_html,
          form_css: form_css,
          recipient: recipient,
          signable: signable,
          signature_confirmation_label: signature_confirmation_label,
          subscription_list_id: subscription_list_id,
          type: type,
          active: active,
          submission_count: submission_count
        }.reject { |_key, value| value.nil? }

        authenticated_post('/api/forms', body: payload)
      end

      def get_form_details(form_id)
        authenticated_get("/api/forms/#{form_id}")
      end

      # The server treats a JSON null the same as omitting the key ("leave
      # unchanged"), so nil values are dropped rather than sent — fields cannot
      # be cleared via this endpoint.
      def update_form(form_id, **attrs)
        payload = attrs.slice(*UPDATABLE_FORM_KEYS).reject { |_key, value| value.nil? }

        require_api_key!
        uri = URI.parse("#{BASE_URL}/api/forms/#{form_id}")
        http = build_http(uri)

        request = Net::HTTP::Put.new(uri.path, auth_headers('Content-Type' => 'application/json'))
        request.body = payload.to_json

        response = http.request(request)
        handle_response(response)
      end

      def archive_form(form_id)
        authenticated_post("/api/forms/#{form_id}/archive")
      end

      def unarchive_form(form_id)
        authenticated_post("/api/forms/#{form_id}/unarchive")
      end

      def copy_form(form_id, title:)
        authenticated_post('/api/forms/copy', body: { form_id: form_id, title: title })
      end

      def form_stats(customer_id: nil)
        query = build_query(customer_id: customer_id)
        authenticated_get("/api/forms/stats#{query}")
      end

      def list_submissions(form_id, page: nil, items: nil, order: nil, order_by: nil, submission_id: nil)
        query = build_query(page: page, items: items, order: order,
                            order_by: order_by, submission_id: submission_id)
        authenticated_get("/api/forms/#{form_id}/submissions#{query}")
      end

      def submissions_csv(form_id, submission_id: nil)
        path = "/api/forms/#{form_id}/submissions/submission-csv"
        path += "/#{submission_id}" if submission_id
        authenticated_get(path, raw: true)
      end

      def submission_pdf(form_id, submission_id)
        authenticated_get("/api/forms/#{form_id}/submissions/#{submission_id}/submission-pdf", raw: true)
      end

      private

      def authenticated_get(path, raw: false)
        require_api_key!
        uri = URI.parse("#{BASE_URL}#{path}")
        http = build_http(uri)

        request = Net::HTTP::Get.new(uri.request_uri, auth_headers)

        response = http.request(request)
        handle_response(response, raw: raw)
      end

      def authenticated_post(path, body: nil)
        require_api_key!
        uri = URI.parse("#{BASE_URL}#{path}")
        http = build_http(uri)

        headers = body ? auth_headers('Content-Type' => 'application/json') : auth_headers
        request = Net::HTTP::Post.new(uri.path, headers)
        request.body = body.to_json if body

        response = http.request(request)
        handle_response(response)
      end

      def auth_headers(extra = {})
        { 'Authorization' => "Bearer #{@api_key}" }.merge(extra)
      end

      def require_api_key!
        return if @api_key

        raise MissingApiKeyError, 'This endpoint requires an API key. Pass api_key: to ' \
                                  'PauboxRails::Forms.client or set the PAUBOX_FORMS_API_KEY ' \
                                  'environment variable.'
      end

      def build_query(params)
        filtered = params.reject { |_key, value| value.nil? }
        return '' if filtered.empty?

        "?#{URI.encode_www_form(filtered)}"
      end

      def build_http(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http
      end

      def handle_response(response, raw: false)
        case response.code.to_i
        when 200
          raw ? response.body : JSON.parse(response.body)
        when 201
          true
        when 400, 422
          raise BadRequestError, "Bad request: #{response.body}"
        when 401
          raise UnauthorizedError, "Unauthorized: #{response.body}"
        when 403
          raise ForbiddenError, "Forbidden: #{response.body}"
        when 404
          raise NotFoundError, 'Form not found'
        else
          raise Error, "Unexpected response #{response.code}: #{response.body}"
        end
      end
    end
  end
end
