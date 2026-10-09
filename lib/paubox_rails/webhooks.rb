require 'paubox_rails/webhooks/client'

module PauboxRails
  module Webhooks
    # The public gateway exposes only /v1/webhooks/endpoints and rewrites it
    # onto the service's own /v1/endpoints, so the producers' event-ingest
    # route is not reachable from here. The bare base is deliberately unrouted;
    # every request this client makes carries the /endpoints resource.
    BASE_URL = 'https://api.paubox.com/v1/webhooks'.freeze

    # Unlike Forms, the base URL is overridable. Staging QA needs it, and
    # hardcoding it is why pointing the Forms client at a non-production
    # environment means editing the gem.
    ENV_BASE_URL = 'PAUBOX_WEBHOOKS_URL'.freeze
    ENV_API_KEY = 'PAUBOX_WEBHOOKS_API_KEY'.freeze

    class Error < StandardError; end
    class NotFoundError < Error; end
    class BadRequestError < Error; end
    class UnauthorizedError < Error; end
    class ForbiddenError < Error; end
    class MissingApiKeyError < Error; end

    def self.client(**options)
      Client.new(**options)
    end
  end
end
