require 'paubox_rails/forms/client'

module PauboxRails
  module Forms
    BASE_URL = 'https://apx.paubox.com/forms'.freeze

    class Error < StandardError; end
    class NotFoundError < Error; end
    class BadRequestError < Error; end

    def self.client
      Client.new
    end
  end
end
