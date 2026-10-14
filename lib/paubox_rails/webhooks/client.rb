require 'net/http'
require 'json'
require 'uri'

module PauboxRails
  module Webhooks
    # Client for the Paubox webhooks service.
    #
    # Authenticates with a scoped API key sent as "Authorization: Bearer
    # <key>" — the same scheme as Forms, and a different one from the Email
    # API's "Token token=". Which events a key may subscribe to is decided by
    # its scopes; asking for one it is not scoped for is refused with 403.
    class Client
      UUID_PATTERN = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/.freeze

      # Net::HTTP ships with no default socket timeouts, so a black-holed
      # connection hangs for the TCP stack default rather than raising. These
      # are tighter than the Forms client's because nothing here streams a
      # CSV or a PDF — every response is a small JSON document.
      DEFAULT_OPEN_TIMEOUT = 10
      DEFAULT_READ_TIMEOUT = 30

      attr_reader :api_key, :base_url

      def initialize(api_key: ENV.fetch(ENV_API_KEY, nil), base_url: nil)
        @api_key = api_key
        @base_url = (base_url || ENV.fetch(ENV_BASE_URL, nil) || BASE_URL).sub(%r{/+\z}, '')
      end

      # Lists the endpoints this key can act on. Endpoints carrying an event
      # the key is not scoped for are filtered out by the service, so this is
      # what the key may manage rather than everything on the account.
      #
      # Returns the full document: "data" plus "page_info". Note page_info
      # "count" is the total number of matching endpoints, not the length of
      # this page.
      def list_webhook_endpoints(page: nil, items: nil)
        authenticated_get("/endpoints#{build_query(page: page, items: items)}")
      end

      # Subscribes a URL to one or more events.
      #
      # The response carries "signing_secret", which the service returns only
      # here — it is absent from get_webhook_endpoint and from the list. Store
      # it on receipt; a lost secret means replacing the endpoint.
      #
      # Event names are not validated here on purpose: the catalog belongs to
      # the service and grows without a gem release. An unknown event comes
      # back as 422, one this key is not scoped for as 403.
      def create_webhook_endpoint(target_url:, events:)
        raise ArgumentError, 'target_url is required' if target_url.nil? || target_url.to_s.empty?
        raise ArgumentError, 'events must not be empty' if events.nil? || Array(events).empty?

        unwrap_data(
          authenticated_post('/endpoints', body: { target_url: target_url, events: Array(events) })
        )
      end

      def get_webhook_endpoint(endpoint_id)
        endpoint_id = path_segment!(endpoint_id, 'endpoint_id')
        unwrap_data(authenticated_get("/endpoints/#{endpoint_id}"))
      end

      # Partial update — only the arguments given are sent, so changing
      # target_url leaves events and status untouched. status accepts
      # "active" or "disabled".
      def update_webhook_endpoint(endpoint_id, target_url: nil, status: nil, events: nil)
        endpoint_id = path_segment!(endpoint_id, 'endpoint_id')

        body = {}
        body[:target_url] = target_url unless target_url.nil?
        body[:status] = status unless status.nil?
        body[:events] = Array(events) unless events.nil?
        raise ArgumentError, 'provide at least one of target_url:, status:, events:' if body.empty?

        unwrap_data(authenticated_patch("/endpoints/#{endpoint_id}", body: body))
      end

      # Deletes an endpoint, stopping every event on it. The service answers
      # 204 with no body, so this returns true rather than a document.
      def delete_webhook_endpoint(endpoint_id)
        endpoint_id = path_segment!(endpoint_id, 'endpoint_id')
        authenticated_delete("/endpoints/#{endpoint_id}")
      end

      private

      # Single resources come back wrapped: {"data": {...}}. Unwrapped here so
      # callers get the endpoint itself rather than having to reach through an
      # envelope that carries nothing else.
      #
      # list_webhook_endpoints deliberately does not use this — its envelope
      # also carries "page_info", which a caller paginating actually needs.
      def unwrap_data(parsed)
        parsed.is_a?(Hash) && parsed.key?('data') ? parsed['data'] : parsed
      end

      # Sanitize a caller-supplied id before interpolating it into a URL path.
      # Without this, a value containing "..", "/", "?" or "#" changes which
      # endpoint is called — and since the Authorization header goes on the
      # same host, the key rides along on the retargeted request. Unlike the
      # Forms client there is no public-endpoint exception here: every id on
      # this service is a UUID, so the strict check applies throughout.
      def path_segment!(value, name)
        raise ArgumentError, "#{name} is required and must not be empty" if value.nil? || value.to_s.empty?

        s = value.to_s
        raise ArgumentError, "#{name} must be a UUID, got #{s.inspect}" if s !~ UUID_PATTERN

        # A no-op for a UUID; kept as defense-in-depth so the guarantee holds
        # if the pattern is ever relaxed.
        URI.encode_www_form_component(s).gsub('+', '%20')
      end

      def authenticated_get(path)
        require_api_key!
        uri = URI.parse("#{@base_url}#{path}")
        request = Net::HTTP::Get.new(uri.request_uri, auth_headers)
        handle_response(build_http(uri).request(request))
      end

      def authenticated_post(path, body: nil)
        require_api_key!
        uri = URI.parse("#{@base_url}#{path}")
        request = Net::HTTP::Post.new(uri.request_uri, auth_headers('Content-Type' => 'application/json'))
        request.body = body.to_json if body
        handle_response(build_http(uri).request(request))
      end

      def authenticated_patch(path, body: nil)
        require_api_key!
        uri = URI.parse("#{@base_url}#{path}")
        request = Net::HTTP::Patch.new(uri.request_uri, auth_headers('Content-Type' => 'application/json'))
        request.body = body.to_json if body
        handle_response(build_http(uri).request(request))
      end

      def authenticated_delete(path)
        require_api_key!
        uri = URI.parse("#{@base_url}#{path}")
        request = Net::HTTP::Delete.new(uri.request_uri, auth_headers)
        handle_response(build_http(uri).request(request))
      end

      def auth_headers(extra = {})
        { 'Authorization' => "Bearer #{@api_key}" }.merge(extra)
      end

      def require_api_key!
        return if @api_key

        raise MissingApiKeyError, 'This endpoint requires an API key. Pass api_key: to ' \
                                  'PauboxRails::Webhooks.client or set the ' \
                                  "#{ENV_API_KEY} environment variable."
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

      # Differs from the Forms client in two ways that matter.
      #
      # 201 returns the parsed body rather than true: create is the only place
      # the signing secret is ever available, and returning true would throw
      # it away irrecoverably.
      #
      # Error messages are unwrapped from the service's {"message": "..."}
      # shape instead of interpolating the raw body, so a caller sees
      # "target_url: must be an https URL" rather than a JSON blob.
      def handle_response(response)
        case response.code.to_i
        when 200, 201
          response.body.to_s.empty? ? true : JSON.parse(response.body)
        when 204
          true
        when 400, 422
          raise BadRequestError, error_message(response)
        when 401
          raise UnauthorizedError, error_message(response)
        when 403
          raise ForbiddenError, error_message(response)
        when 404
          raise NotFoundError, 'Webhook endpoint not found'
        else
          raise Error, "Unexpected response #{response.code}: #{response.body}"
        end
      end

      # Falls back to the raw body so an unexpected shape still reaches the
      # caller rather than becoming an empty message.
      def error_message(response)
        parsed = JSON.parse(response.body.to_s)
        parsed.is_a?(Hash) && parsed['message'] ? parsed['message'] : response.body.to_s
      rescue JSON::ParserError
        response.body.to_s
      end
    end
  end
end
