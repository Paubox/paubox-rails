require 'net/http'
require 'json'
require 'uri'

module PauboxRails
  module Forms
    class Client
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

      private

      def build_http(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http
      end

      def handle_response(response)
        case response.code.to_i
        when 200
          JSON.parse(response.body)
        when 201
          true
        when 400
          raise BadRequestError, "Bad request: #{response.body}"
        when 404
          raise NotFoundError, 'Form not found'
        else
          raise Error, "Unexpected response #{response.code}: #{response.body}"
        end
      end
    end
  end
end
