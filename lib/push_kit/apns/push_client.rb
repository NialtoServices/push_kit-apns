# frozen_string_literal: true

module PushKit
  module APNS
    # The PushClient class provides an interface for delivering push notifications using HTTP/2.
    #
    class PushClient
      # @return [Hash] The default hosts for each of the environments supported by APNS.
      #
      HOSTS = {
        production: 'api.push.apple.com',
        development: 'api.development.push.apple.com'
      }.freeze

      # @return [Hash] The default port numbers supported by APNS.
      #
      PORTS = {
        default: 443,
        alternative: 2197
      }.freeze

      # @return [String] The host to use when connecting to the server.
      #
      attr_reader :host

      # @return [Integer] The port to use when connecting to the server.
      #
      attr_reader :port

      # @return [String] The APNS topic, usually the app's bundle identifier.
      #
      attr_reader :topic

      # @return [PushKit::APNS::TokenGenerator] The token generator to authenticate requests with.
      #
      attr_reader :token_generator

      # Creates a new PushClient for the specified environment and port.
      #
      # You can manually specify the host like 'api.push.apple.com' or use the convenience symbols :production and
      # :development which correspond to the host for that environment.
      #
      # You can also manually manually specify a port number like 443 or use the convenience symbols :default and
      # :alternative which correspond to the port numbers in Apple's documentation.
      #
      # @param options         [Hash]                          The options for the client:
      #        host            [String|Symbol]                 The host (can also be :production or :development).
      #        port            [Integer|Symbol]                The port number (can also be :default or :alternative).
      #        topic           [String]                        The APNS topic (matches the app's bundle identifier).
      #        token_generator [PushKit::APNS::TokenGenerator] The token generator to authenticate the requests with.
      #
      def initialize(options = {})
        extract_host(options)
        extract_port(options)
        extract_topic(options)
        extract_token_generator(options)
      end

      # Deliver one or more notifications.
      #
      # @param notifications [Splat] The notifications to deliver.
      #
      def deliver(*notifications, &block)
        unless notifications.all?(Notification)
          raise ArgumentError, 'The notifications must all be instances of PushKit::APNS::Notification.'
        end

        latch = Concurrent::CountDownLatch.new(notifications.count)

        notifications.each do |notification|
          deliver_single(notification) do |*args|
            latch.count_down
            block.call(*args) if block.is_a?(Proc)
          end
        end

        latch.wait

        nil
      end

      private

      # @return [HTTPClient] The HTTP client.
      #
      def client
        @client ||= HTTPClient.new("https://#{host}:#{port}")
      end

      # Deliver a single notification.
      #
      # @param  notification [PushKit::APNS::Notification] The notification to deliver.
      # @return              [Boolean]                     Whether the notification was sent.
      #
      def deliver_single(notification, &block)
        token = notification.device_token

        unless token.is_a?(String) && token.length.positive?
          raise ArgumentError, 'The notification must have a device token.'
        end

        headers = headers(notification)
        payload = notification.payload.to_json

        request = { method: :post, path: "/3/device/#{token}", headers: headers, body: payload }

        client.request(**request) do |code, response_headers, response_body|
          handle_result(notification, code, response_headers, response_body, &block)
        end
      end

      # Handle the result of a single delivery.
      #
      # @param notification [PushKit::APNS::Notification] The notification to handle delivery of.
      # @param code         [Integer]                     The response status code.
      # @param headers      [Hash]                        The response headers.
      # @param body         [String]                      The response body.
      # @param block        [Proc]                        A block to call after processing the response.
      #
      def handle_result(notification, code, headers, body, &block)
        uuid = headers['apns-id']
        notification.uuid = uuid if uuid.is_a?(String) && uuid.length.positive?

        success = code.between?(200, 299)

        begin
          result = JSON.parse(body)
        rescue JSON::JSONError
          result = nil
        end

        return unless block.is_a?(Proc)

        block.call(notification, success, result)
      end

      # Returns the additional request headers for a notification.
      #
      # @param  notification [PushKit::APNS::Notification] The notification to compute additional headers for.
      # @return              [Hash]                        The additional headers for the notification.
      #
      def headers(notification)
        headers = {
          'content-type' => 'application/json',
          'apns-topic' => topic
        }

        headers.merge!(token_generator.headers)
        headers.merge!(notification.headers)

        headers.each_with_object({}) do |(key, value), hash|
          hash[key] = value.to_s unless value.nil?
        end
      end

      # Extract the :host attribute from the options and store it in an instance variable.
      #
      # @param options [Hash] The options passed in to the `initialize` method.
      #
      def extract_host(options)
        @host = options[:host]
        @host = HOSTS[@host] if @host.is_a?(Symbol)

        return if @host.is_a?(String) && @host.length.positive?

        raise ArgumentError, 'The :host attribute must be provided.'
      end

      # Extract the :port attribute from the options and store it in an instance variable.
      #
      # @param options [Hash] The options passed in to the `initialize` method.
      #
      def extract_port(options)
        @port = options[:port]
        @port = PORTS[@port] if @port.is_a?(Symbol)

        return if @port.is_a?(Integer) && @port.between?(1, 655_35)

        raise ArgumentError, 'The :port must be a number between 1 and 65535.'
      end

      # Extract the :topic attribute from the options and store it in an instance variable.
      #
      # @param options [Hash] The options passed in to the `initialize` method.
      #
      def extract_topic(options)
        @topic = options[:topic]

        return if @topic.is_a?(String) && @topic.length.positive?

        raise ArgumentError, 'The :topic must be provided.'
      end

      # Extract the :token_generator attribute from the options and store it in an instance variable.
      #
      # @param options [Hash] The options passed in to the `initialize` method.
      #
      def extract_token_generator(options)
        @token_generator = options[:token_generator]

        return if @token_generator.is_a?(TokenGenerator)

        raise ArgumentError, 'The :token_generator attribute must be a `PushKit::APNS::TokenGenerator` instance.'
      end
    end
  end
end
