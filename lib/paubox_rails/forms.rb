require 'paubox_rails/forms/client'

module PauboxRails
  module Forms
    BASE_URL = 'https://apx.paubox.com/forms'.freeze

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
