# frozen_string_literal: true

module PushKit
  module APNS
    class Notification
      # The Localization class provides a way to localize specific notification attributes.
      #
      # You can localize the :title, :subtitle and :body attributes of a notification.
      #
      class Localization
        # @return [String] The localization key as defined in your app's localization file.
        #
        attr_accessor :key

        # @return [Array] The arguments used to format the localization string.
        #
        attr_accessor :arguments

        # Creates a Localization instance which wraps the given localization key and it's formatting arguments.
        #
        # @param key       [String] The key as defined in your app's localization file.
        # @param arguments [Array]  The arguments to format the localization string with.
        #
        def initialize(key: nil, arguments: nil)
          @key = key
          @arguments = arguments
        end

        # Returns a payload which can be merged into the :alert Hash within the notification's payload.
        #
        # @param  attribute [Symbol] The attribute to generate the payload for.
        # @return           [Hash]   The partial payload to merge into the notification's payload.
        #
        def payload(attribute)
          prefix = prefix(attribute)

          return nil unless prefix.is_a?(String)

          components = { "#{prefix}loc-key" => @key }
          components["#{prefix}loc-args"] = arguments if arguments.is_a?(Array) && arguments.any?
          components
        end

        private

        # Returns the prefix for keys in the payload.
        #
        # @param  attribute [Symbol] The attribute to determine the prefix for.
        # @return           [String] The prefix for the keys in the payload.
        #
        def prefix(attribute)
          case attribute
          when :title    then 'title-'
          when :subtitle then 'subtitle-'
          when :body     then ''
          end
        end
      end
    end
  end
end
