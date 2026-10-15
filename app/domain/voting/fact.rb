module Voting
  class Fact < RubyEventStore::Event
    class << self
      def strict(data:)
        validate_data!(data)
        new(data: data)
      end

      private

      def validate_data!(data)
        missing_keys = const_get(:SCHEMA).keys - data.keys
        raise ArgumentError, "Missing event data: #{missing_keys.join(', ')}" if missing_keys.any?

        const_get(:SCHEMA).each do |key, expected_types|
          value = data.fetch(key)
          types = Array(expected_types)
          next if types.any? { |type| value.is_a?(type) }

          raise ArgumentError, "Invalid #{key}: expected #{types.join(' or ')}"
        end
      end
    end

    def stream_names
      [ "Event$#{data_value(:event_id)}", "User$#{data_value(:user_id)}" ]
    end

    private

    def data_value(key)
      data.fetch(key) { data.fetch(key.to_s) }
    end
  end
end
