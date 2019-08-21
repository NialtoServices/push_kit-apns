# frozen_string_literal: true

module PushKit
  module APNS
    # The Notification class is used to build a payload that can be delivered by APNS.
    #
    class Notification
      # The acceptable notification priorities.
      #
      # :eco       - Send the push message at a time that takes into account power considerations for the device.
      #              Notifications with this priority might be grouped and delivered in bursts.
      #              They are throttled, and in some cases are not delivered.
      #
      # :immediate - Send the push message immediately. Notifications with this priority must trigger an alert, sound,
      #              or badge on the target device.
      #              It is an error to use this priority for a push notification that contains only the
      #              content-available key.
      #
      # @return [Hash]
      #
      PRIORITIES = { eco: 5, immediate: 10 }.freeze

      # The title of the notification.
      #
      # @return [String|PushKit::APNS::Notification::Localization]
      #
      attr_accessor :title

      # The subtitle of the notification.
      #
      # @return [String|PushKit::APNS::Notification::Localization]
      #
      attr_accessor :subtitle

      # The body of the notification.
      #
      # @return [String|PushKit::APNS::Notification::Localization]
      #
      attr_accessor :body

      # The badge number to assign to the app's icon on the home screen.
      #
      # @return [Integer]
      #
      attr_accessor :badge

      # The name of a sound file included in your app's bundle to play when the notification is received.
      #
      # Alternatively, you can specify :default to play the device's default notification sound chosen by the user.
      #
      # @return [String]
      #
      attr_accessor :sound

      # The localization key for the title of the action button in the notification.
      #
      # When provided, the system displays an alert that includes both the 'Close' and 'View' buttons.
      # The value is used as a key to get a localized string in the current localization to use for the right button's
      # title (which is the action button) instead of the default 'View' text.
      #
      # @return [String]
      #
      attr_accessor :action_key

      # The notification's category matching one of your app's registered categories.
      #
      # @return [String]
      #
      attr_accessor :category

      # The filename of an image in your app's bundle, with or without the filename extension.
      #
      # The image is used as the launch image when users tap the action button or move the action slider.
      # If this property is not specified, the system either uses the previous snapshot, uses the image identified by
      # the UILaunchImageFile key in your app's Info.plist file, or falls back to 'Default.png'.
      #
      # @return [String]
      #
      attr_accessor :launch_image

      # An array of custom attributes to add to the root of the payload.
      #
      # Bear in mind that the size of a payload is limited to these sizes:
      #   For regular remote notifications, the maximum size of the payload is 4KB (4096 bytes).
      #   For Voice over Internet Protocol (VoIP) notifications, the maximum size is 5KB (5120 bytes).
      #
      # @return [Hash]
      #
      attr_accessor :metadata

      # Indicate that the notification should trigger a background update.
      #
      # When enabled, the system wakes up your app in the background and delivers the notification to its app delegate.
      # The notification is delivered without presenting any visual or auditory notification to the user.
      #
      # @return [Boolean]
      #
      attr_accessor :content_available

      # Indicate that the notification has mutable content.
      #
      # When enabled, the system will use an extension in your app to allow you to make modifications to the
      # notification before it is delivered to the user.
      #
      # @return [Boolean]
      #
      attr_accessor :mutable_content

      # A canonical UUID that identifies the notification.
      #
      # You can generate a UUID using `SecureRandom.uuid`.
      # If there is an error sending the notification, APNS uses this value to identify the notification to your server.
      # If you omit this attribute, a new UUID is created by APNS when sending the notification.
      #
      # @return [String]
      #
      attr_accessor :uuid

      # The collapse identifier for the notification.
      #
      # Multiple notifications with the same collapse identifier are displayed to the user as a single notification.
      # The value of this attribute must not exceed 64 bytes.
      #
      # @return [String]
      #
      attr_accessor :collapse_uuid

      # The priority of the notification.
      #
      # This can either be an Integer representing a specific priority, or one of the symbols from the PRIORITIES
      # constant.
      #
      # @return [Integer|Symbol]
      #
      attr_accessor :priority

      # The time when the notification is no longer valid and can be discarded.
      #
      # If this value is nonzero, APNS stores the notification and tries to deliver it at least once,
      # repeating the attempt as needed if it is unable to deliver the notification the first time.
      # If the value is 0, APNS treats the notification as if it expires immediately and does not store the
      # notification or attempt to redeliver it.
      #
      # @return [Time]
      #
      attr_accessor :expiration

      # The token representing a device capable of receiving notifications.
      #
      # @return [String]
      #
      attr_accessor :device_token

      # Creates a new notification.
      #
      def initialize
        @content_available = false
        @mutable_content = false
      end

      # @return [Integer] The actual priority value required by APNS.
      #
      def apns_priority
        return priority unless priority.is_a?(Symbol)

        PRIORITIES[priority]
      end

      # @return [Integer] The actual expiration time value required by APNS.
      #
      def apns_expiration
        return expiration unless expiration.is_a?(Time)

        expiration.utc.to_i
      end

      # Duplicate this notification for each of the provided tokens, setting the token on the notification.
      #
      # @param  tokens [Splat] A collection of device tokens to duplicate the notification for.
      # @return        [Array] A collection notifications, one for each of the device tokens.
      #
      def for_tokens(*tokens)
        tokens.map do |token|
          notification = dup
          notification.device_token = token
          notification
        end
      end

      # @return [Hash] The headers to include in the HTTP/2 request.
      #
      def headers
        headers = {}
        headers['apns-id'] = uuid                      if uuid.is_a?(String)
        headers['apns-collapse-id'] = collapse_uuid    if collapse_uuid.is_a?(String)
        headers['apns-priority'] = apns_priority       if apns_priority.is_a?(Integer)
        headers['apns-expiration'] = apns_expiration   if apns_expiration.is_a?(Integer)
        headers
      end

      # @return [Hash] The payload to use as the body of the HTTP/2 request.
      #
      def payload
        payload = metadata.is_a?(Hash) ? metadata.dup : {}

        if (aps = payload_aps) && aps.any?
          payload['aps'] = aps
        end

        payload
      end

      private

      # @return [Hash] The contents of the key path ':aps' within the payload.
      #
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def payload_aps
        aps = {}

        if (alert = payload_alert) && alert.any?
          aps['alert'] = alert
        end

        aps['badge'] = badge           if badge.is_a?(Integer)
        aps['sound'] = sound.to_s      if sound.is_a?(String) || sound.is_a?(Symbol)
        aps['category'] = category     if category.is_a?(String)
        aps['content-available'] = '1' if content_available
        aps['mutable-content'] = '1'   if mutable_content

        aps
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      # @return [Hash] The contents of the key path ':aps -> :alert' within the payload.
      #
      def payload_alert
        alert = {}

        { 'title' => title, 'subtitle' => subtitle, 'body' => body }.each do |key, value|
          if value.is_a?(String)
            alert[key] = value
          elsif value.is_a?(Localization)
            alert.merge!(value.payload(key.to_sym))
          end
        end

        alert['action-loc-key'] = action_key if action_key.is_a?(String)
        alert['launch-image'] = launch_image if launch_image.is_a?(String)

        alert
      end
    end
  end
end
