require 'net/http'
require 'json'
require 'uri'

module PauboxRails
  module Forms
    class Client
      UPDATABLE_FORM_KEYS = %i[title description form_json vanity_url recipient active subscription_list_id].freeze
      UUID_PATTERN = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/.freeze

      # Net::HTTP has no default socket timeouts — a black-holed connection
      # can hang for the TCP stack default (~2 minutes) rather than raising
      # promptly. These are deliberately generous for CSV/PDF exports; a
      # caller with tighter latency budgets can still wrap the call in its
      # own Timeout.
      DEFAULT_OPEN_TIMEOUT = 10
      DEFAULT_READ_TIMEOUT = 60

      attr_reader :api_key

      def initialize(api_key: ENV.fetch('PAUBOX_FORMS_API_KEY', nil))
        @api_key = api_key
      end

      def get_form(form_id)
        # require_uuid: false — the public endpoint predates 0.3.0 and may have
        # existing callers passing non-UUID ids; rejecting anything but UUID
        # here would be a breaking change. Percent-encoding + dot-segment
        # rejection still closes the path-splicing vector for this call.
        form_id = path_segment!(form_id, 'form_id', require_uuid: false)
        uri = URI.parse("#{BASE_URL}/public/form_data/#{form_id}")
        http = build_http(uri)
        response = http.get(uri.path)
        handle_response(response)
      end

      def submit_form(form_id, form_data:, attachments: nil)
        form_id = path_segment!(form_id, 'form_id', require_uuid: false)
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
        form_id = path_segment!(form_id, 'form_id')
        authenticated_get("/api/forms/#{form_id}")
      end

      # The server treats a JSON null the same as omitting the key ("leave
      # unchanged"), so nil values are dropped rather than sent — fields cannot
      # be cleared via this endpoint.
      def update_form(form_id, **attrs)
        form_id = path_segment!(form_id, 'form_id')
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
        form_id = path_segment!(form_id, 'form_id')
        authenticated_post("/api/forms/#{form_id}/archive")
      end

      def unarchive_form(form_id)
        form_id = path_segment!(form_id, 'form_id')
        authenticated_post("/api/forms/#{form_id}/unarchive")
      end

      # copy_form's form_id is a JSON body field, not a URL path segment, so
      # the path-splicing risk does not apply. The server owns the shape check.
      def copy_form(form_id, title:)
        authenticated_post('/api/forms/copy', body: { form_id: form_id, title: title })
      end

      def form_stats(customer_id: nil)
        query = build_query(customer_id: customer_id)
        authenticated_get("/api/forms/stats#{query}")
      end

      def list_submissions(form_id, page: nil, items: nil, order: nil, order_by: nil, submission_id: nil)
        form_id = path_segment!(form_id, 'form_id')
        # submission_id here is a query param, not a URL path segment —
        # URI.encode_www_form takes care of encoding it.
        query = build_query(page: page, items: items, order: order,
                            order_by: order_by, submission_id: submission_id)
        authenticated_get("/api/forms/#{form_id}/submissions#{query}")
      end

      def submissions_csv(form_id, submission_id: nil)
        form_id = path_segment!(form_id, 'form_id')
        path = "/api/forms/#{form_id}/submissions/submission-csv"
        if submission_id
          submission_id = path_segment!(submission_id, 'submission_id')
          path += "/#{submission_id}"
        end
        authenticated_get(path, raw: true)
      end

      def submission_pdf(form_id, submission_id)
        form_id = path_segment!(form_id, 'form_id')
        submission_id = path_segment!(submission_id, 'submission_id')
        authenticated_get("/api/forms/#{form_id}/submissions/#{submission_id}/submission-pdf", raw: true)
      end

      private

      # Sanitize a caller-supplied value before interpolating it into a URL
      # path segment. Without this, a value containing "..", "/", "?", or "#"
      # changes which endpoint is called — and because the authenticated
      # methods send the Authorization header on the same host, the bearer
      # token rides along on the retargeted request. Rejecting non-UUID input
      # up front is the tightest fix; percent-encoding is kept as
      # defense-in-depth so the guarantee holds even if require_uuid is ever
      # relaxed.
      #
      # require_uuid: false is used only for the two long-standing public
      # respondent methods (get_form, submit_form), where a hard UUID
      # requirement would break existing callers. Dot-segments and empty
      # strings are still rejected there.
      def path_segment!(value, name, require_uuid: true)
        raise ArgumentError, "#{name} is required and must not be empty" if value.nil? || value.to_s.empty?

        s = value.to_s
        raise ArgumentError, "#{name} must not be #{s.inspect}, which is not a valid id" if s == '.' || s == '..'

        if require_uuid && s !~ UUID_PATTERN
          raise ArgumentError, "#{name} must be a UUID, got #{s.inspect}"
        end

        # For a UUID this is a no-op; for the public-endpoint fallback it
        # blocks "/", "?", and "#" from splicing the URL.
        URI.encode_www_form_component(s).gsub('+', '%20')
      end

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
        http.open_timeout = DEFAULT_OPEN_TIMEOUT
        http.read_timeout = DEFAULT_READ_TIMEOUT
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
