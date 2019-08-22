# frozen_string_literal: true

require 'concurrent'
require 'http/2'
require 'json'
require 'jwt'
require 'openssl'
require 'securerandom'
require 'uri'

require 'push_kit/apns/constants'
require 'push_kit/apns/notification/localization'
require 'push_kit/apns/notification'
require 'push_kit/apns/http_client'
require 'push_kit/apns/token_generator'
require 'push_kit/apns/push_client'

module PushKit
  # PushKit::APNS provides an easy-to-use API for creating and then delivering notifications via the
  # Apple Push Notification service.
  #
  module APNS
    # Read the key from the file at the specified path.
    #
    # @param  path [String]            Path to a key file.
    # @return      [OpenSSL::PKey::EC] The loaded key.
    #
    def self.load_key(path)
      raise ArgumentError, 'The :key must be a String'            unless path.is_a?(String)
      raise ArgumentError, "The key file does not exist: #{path}" unless File.file?(path)

      OpenSSL::PKey::EC.new(File.read(path))
    end

    # Create a new PushClient instance.
    #
    # @param  options [Hash]
    #         host    [String|Symbol]             The host (can also be :production or :development).
    #         port    [Integer|Symbol]            The port number (can also be :default or :alternative).
    #         topic   [String]                    The APNS topic (matches the app's bundle identifier).
    #         key     [OpenSSL::PKey::EC]         The elliptic curve key to use for authentication.
    #         key_id  [String]                    The identifier for the elliptic curve key.
    #         team_id [String]                    The identifier for the Apple Developer team.
    #         topic   [String]                    The topic for your application (usually the bundle identifier).
    # @return         [PushKit::APNS::PushClient] A client.
    #
    def self.client(options = {})
      options = {
        host: :development,
        port: :default
      }.merge(options)

      token_generator = TokenGenerator.new(
        key: options[:key],
        key_id: options[:key_id],
        team_id: options[:team_id]
      )

      PushClient.new(
        host: options[:host],
        port: options[:port],
        topic: options[:topic],
        token_generator: token_generator
      )
    end

    # @return [Hash] A collection of `PushKit::APNS::PushClient` instances.
    #
    def self.clients
      @clients ||= {}
    end

    # Prepare a client.
    #
    # This method creates a `PushKit::APNS::PushClient` instance using the #client method, then stores it in the
    # #clients Hash using an identifier you specify.
    # Storing the clients in this way provides on-demand access without requiring the use of global variables.
    #
    # @param identifier [Symbol] The key to use within the #clients Hash.
    # @param options    [Hash]   The options to pass to the #client method.
    #
    def self.prepare(identifier, options = {})
      clients[identifier] = client(options)
    end
  end
end
