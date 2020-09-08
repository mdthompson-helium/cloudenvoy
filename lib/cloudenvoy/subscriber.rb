# frozen_string_literal: true

module Cloudenvoy
  # Use this module to define subscribers. Subscribers must implement
  # the message processsing logic in the `process` method.
  #
  # E.g.
  #
  # class UserSubscriber
  #   include Cloudenvoy::Subscriber
  #
  #   # Specify subscription options
  #   cloudenvoy_options topics: ['my-topic']
  #
  #   # Process message objects
  #   def process(message)
  #     ...do something...
  #   end
  # end
  #
  module Subscriber
    # Add class method to including class
    def self.included(base)
      base.extend(ClassMethods)
      base.attr_accessor :message

      # Register subscriber
      Cloudenvoy.subscribers.add(base)
    end

    #
    # Return the subscriber class for the provided
    # class name.
    #
    # @param [String] sub_uri The subscription uri.
    #
    # @return [Class] The subscriber class
    #
    def self.from_sub_uri(sub_uri)
      klass_name = Subscriber.parse_sub_uri(sub_uri)[0]

      # Check that subscriber class is a valid subscriber
      sub_klass = Object.const_get(klass_name.camelize)

      sub_klass.include?(self) ? sub_klass : nil
    end

    #
    # Parse the subscription name and return the subscriber name and topic.
    #
    # @param [String] sub_uri The subscription URI
    #
    # @return [Array<String,String>] A tuple [subscriber_name, topic ]
    #
    def self.parse_sub_uri(sub_uri)
      sub_uri.split('/').last.split('.').last(2)
    end

    #
    # Execute a subscriber from a payload object received from
    # Pub/Sub.
    #
    # @param [Hash] input_payload The Pub/Sub webhook hash describing
    # the message to process.
    #
    # @return [Any] The subscriber processing return value.
    #
    def self.execute_from_descriptor(input_payload)
      message = Message.from_descriptor(input_payload)
      subscriber = message.subscriber || raise(InvalidSubscriberError)
      subscriber.execute
    end

    # Module class methods
    module ClassMethods
      #
      # Set the subscriber runtime options.
      #
      # @param [Hash] opts The subscriber options.
      #
      # @return [Hash] The options set.
      #
      def cloudenvoy_options(opts = {})
        opt_list = opts&.map { |k, v| [k.to_sym, v] } || [] # symbolize
        @cloudenvoy_options_hash = Hash[opt_list]
      end

      #
      # Return the subscriber runtime options.
      #
      # @return [Hash] The subscriber runtime options.
      #
      def cloudenvoy_options_hash
        @cloudenvoy_options_hash || {}
      end

      #
      # Return the list of topics this subscriber listens
      # to.
      #
      # @return [Array<String>] The list of subscribed topics.
      #
      def topics
        cloudenvoy_options_hash[:topics] || []
      end

      #
      # Return the subscription name used by this subscriber
      # to subscribe to a specific topic.
      #
      # @return [String] The subscription name.
      #
      def subscription_name(topic)
        [
          Cloudenvoy.config.gcp_sub_prefix.tr('.', '-'),
          to_s.underscore,
          topic
        ]
      end

      #
      # Create the Subscriber subscription in Pub/Sub.
      #
      # @return [Array<Google::Cloud::PubSub::Subscription>] The upserted subscription.
      #
      def setup
        topics.map do |t|
          PubSubClient.upsert_subscription(t, subscription_name(t))
        end
      end
    end

    #
    # Build a new subscriber instance.
    #
    # @param [Cloudenvoy::Message] message The message to process.
    #
    def initialize(message:)
      @message = message
    end

    #
    # Return the Cloudenvoy logger instance.
    #
    # @return [Logger, any] The cloudenvoy logger.
    #
    def logger
      @logger ||= SubscriberLogger.new(self)
    end

    #
    # Execute the subscriber's logic.
    #
    # @return [Any] The logic return value
    #
    def execute
      logger.info('Processing message...')

      # Process message
      resp = process(message)

      # Log completion and return result
      logger.info('Message processed')
      resp
    rescue StandardError => e
      logger.info('Message processing failed')
      raise(e)
    end

    #
    # Equality operator.
    #
    # @param [Any] other The object to compare.
    #
    # @return [Boolean] True if the object is equal.
    #
    def ==(other)
      other.is_a?(self.class) && other.message == message
    end
  end
end