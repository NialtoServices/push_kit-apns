# frozen_string_literal: true

module PushKit
  module APNS
    # The TokenGenerator class provides an API for creating JSON Web Tokens used to authenticate requests to the APNS
    # system.
    #
    class TokenGenerator
      # @return [String] The team identifier.
      #
      attr_reader :team_id

      # @return [String] The key identifier.
      #
      attr_reader :key_id

      # Create a new AutoToken instance.
      #
      # @param  team_id [String]                        The team identifier.
      # @param  key_id  [String]                        The key identifier.
      # @param  key     [OpenSSL::PKey::EC]             The private key.
      # @return         [PushKit::APNS::TokenGenerator] A TokenGenerator instance.
      #
      def initialize(key: nil, key_id: nil, team_id: nil)
        raise ArgumentError, 'The :key attribute must be an OpenSSL::PKey::EC.'   unless key.is_a?(OpenSSL::PKey::EC)
        raise ArgumentError, 'The :key attribute must contain a private key.'     unless key.private_key?
        raise ArgumentError, 'The :key_id attribute must be a String.'            unless key_id.is_a?(String)
        raise ArgumentError, 'The :key_id attribute does not appear to be valid.' unless key_id.length == 10
        raise ArgumentError, 'The :team_id attribute must be a String.'           unless team_id.is_a?(String)

        @key = key
        @key_id = key_id
        @team_id = team_id
      end

      # @return [String] The token to use for authentication.
      #
      def token
        return @token unless generate_token?

        mutex.synchronize do
          next @token unless generate_token?

          @generated_at = time
          @token = generate_token
        end
      end

      # @return [Hash] The authentication headers.
      #
      def headers
        {
          'authorization' => 'Bearer ' + token
        }
      end

      private

      # @return [OpenSSL::PKey::EC] The private key.
      #
      attr_reader :key

      # @return [Time] The time the current token was generated.
      #
      attr_reader :generated_at

      # @return [Mutex] The mutex used to generate a new token.
      #
      def mutex
        @mutex ||= Mutex.new
      end

      # @return [Boolean] Does a token need to be generated?
      #
      def generate_token?
        @token.nil? || generated_at.nil? || generated_at < (time - 3000)
      end

      # Generate a JSON Web Token based on the current time for authentication.
      #
      # @return [String] The newly generated token.
      #
      def generate_token
        headers = { 'kid' => key_id }
        claims  = { 'iat' => time, 'iss' => team_id }

        JWT.encode(claims, key, 'ES256', headers)
      end

      # @return [Integer] The current UTC time in seconds.
      #
      def time
        Time.now.utc.to_i
      end
    end
  end
end
