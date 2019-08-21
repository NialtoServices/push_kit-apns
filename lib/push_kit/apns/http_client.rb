# frozen_string_literal: true

module PushKit
  module APNS
    # The HTTPClient class provides a minimal HTTP/2 client.
    #
    class HTTPClient
      # @return [String] The ALPN protocol required by HTTP/2.
      #
      ALPN_PROTOCOL = 'h2'

      # @return [URI] The URI which indicates the scheme, host and port of the remote server.
      #
      attr_reader :uri

      # Creates a new HTTPClient.
      #
      # @param uri [String|URI] A URI which indicates the scheme, host and port of the remote server.
      #
      def initialize(uri)
        case uri
        when String then @uri = URI(uri)
        when URI    then @uri = uri
        else             raise 'Expected the :uri attribute to be a String or a URI.'
        end
      end

      # Perform a HTTP request.
      #
      # @param method  [String|Symbol] The request method (:get, :post, etc).
      # @param path    [String]        The request path.
      # @param headers [Hash]          The request headers.
      # @param body    [String]        The request body.
      # @param block   [Proc]          A block to call once the request has completed.
      #
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      #
      def request(method: nil, path: nil, headers: nil, body: nil, &block)
        raise 'The :method should be a String or a Symbol' unless method.is_a?(String) || method.is_a?(Symbol)
        raise 'The :path should be a String'               unless path.is_a?(String)
        raise 'The :headers should be a Hash'              unless headers.nil? || headers.is_a?(Hash)
        raise 'The :body should be a String'               unless body.nil? || body.is_a?(String)
        raise 'The completion block must be provided.'     unless block.is_a?(Proc)

        requests.push(method: method, path: path, headers: headers, body: body, completion: block)

        perform_requests

        nil
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      private

      # @return [Mutex] The semaphore used to ensure only one #perform_requests method call executes at a time.
      #
      def perform_requests_mutex
        @perform_requests_mutex ||= Mutex.new
      end

      # @return [Queue] The queue containing requests that need to be processed.
      #
      def requests
        @requests ||= Queue.new
      end

      # @return [OpenSSL::SSL::SSLSocket|TCPSocket] An SSL or TCP socket.
      #
      def socket
        ssl_socket || tcp_socket
      end

      # Reset the client and sockets if the connection is broken.
      #
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      #
      def reset_if_required!
        socket = @ssl_socket || @tcp_socket

        return unless socket.nil? || socket.closed? || @client.nil? || @client.closed?

        @ssl_socket.close unless @ssl_socket.nil? || @ssl_socket.closed?
        @tcp_socket.close unless @tcp_socket.nil? || @tcp_socket.closed?

        @ssl_socket = nil
        @tcp_socket = nil
        @client = nil
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      # @return [HTTP2::Client] An HTTP/2 client.
      #
      def client
        reset_if_required!

        return @client unless @client.nil? || @client.closed?

        @client = HTTP2::Client.new

        @client.on(:frame) do |bytes|
          next if socket.closed?

          socket.print(bytes)
          socket.flush
        end

        @client.send_connection_preface

        # The @client instance variable must exist before calling this method!
        spawn_input_thread

        @client
      end

      # @return [TCPSocket] The TCP socket.
      #
      def tcp_socket
        return @tcp_socket unless @tcp_socket.nil? || @tcp_socket.closed?

        @tcp_socket = TCPSocket.new(uri.host, uri.port)
      end

      # @return [OpenSSL::SSL::SSLSocket] An SSL socket.
      #
      def ssl_socket
        return @ssl_socket unless @ssl_socket.nil? || @ssl_socket.closed?

        # Only create the SSLSocket if the URI requires a secure connection.
        return nil unless uri.scheme == 'https'

        socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
        socket.sync_close = true
        socket.hostname = uri.host
        socket.connect

        if socket.alpn_protocol != ALPN_PROTOCOL
          raise "Expected ALPN protocol '#{ALPN_PROTOCOL}' but received '#{socket.alpn_protocol}'."
        end

        @ssl_socket = socket
      end

      # @return [OpenSSL::SSL::SSLContext] An SSL context.
      #
      def ssl_context
        context = OpenSSL::SSL::SSLContext.new
        context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        context.alpn_protocols = [ALPN_PROTOCOL]
        context.alpn_select_cb = lambda do |protocols|
          ALPN_PROTOCOL if protocols.include?(ALPN_PROTOCOL)
        end

        context
      end

      # Loop over the requests in the queue, performing them until we've emptied the queue or we've hit
      # the concurrent stream limit.
      #
      def perform_requests
        return unless perform_requests_mutex.try_lock

        loop do
          begin
            request = requests.pop(true)
            perform_request(request)
          rescue HTTP2::Error::StreamLimitExceeded
            requests.push(request)
            break
          rescue ThreadError
            break
          end
        end

        perform_requests_mutex.unlock
      end

      # @param request [Hash] The request.
      #
      def perform_request(request)
        stream = client.new_stream

        if (block = request[:completion])
          handle_response(stream, &block)
        end

        headers = headers(request)
        body = request[:body]

        if body.is_a?(String)
          stream.headers(headers, end_stream: false)
          stream.data(body, end_stream: true)
        else
          stream.headers(headers, end_stream: true)
        end
      end

      # @param stream [HTTP2::Stream] The unique stream for the request.
      # @param block  [Proc]          A block to call once the request has completed.
      #
      def handle_response(stream, &block)
        return unless block.is_a?(Proc)

        response_headers = {}
        response_body = String.new

        stream.on(:headers) do |headers|
          response_headers.merge!(Hash[headers])
        end

        stream.on(:data) do |data|
          response_body.concat(data)
        end

        stream.on(:close) do
          perform_requests

          status = response_headers[':status']
          status = status.to_i if status.is_a?(String)
          status = nil unless status.is_a?(Integer)

          block.call(status, response_headers, response_body)
        end
      end

      # @param  request [Hash] The request.
      # @return         [Hash] The request headers.
      #
      def headers(request)
        return nil unless request.is_a?(Hash)
        return nil unless (method = request[:method])
        return nil unless (path = request[:path])

        headers = {
          ':scheme' => uri.scheme,
          ':authority' => [uri.host, uri.port].join(':'),
          ':method' => method.to_s.upcase,
          ':path' => path.to_s
        }

        body = request[:body]
        headers['content-length'] = body.length.to_s if body.is_a?(String)

        headers.merge!(request[:headers]) if request[:headers].is_a?(Hash)

        headers
      end

      # Spawn a thread to wrap the #input_loop method.
      #
      def spawn_input_thread
        return if @input_thread&.alive?

        @input_thread = Thread.new { input_loop }
      end

      # Start a continuous loop, reading bytes from the socket and passing them to the HTTP/2 client.
      #
      def input_loop
        loop do
          break if @client.nil? || @client.closed? || socket.closed? || socket.eof?

          begin
            @client << socket.read_nonblock(1024)
          rescue StandardError
            socket.close

            raise
          end
        end
      end
    end
  end
end
