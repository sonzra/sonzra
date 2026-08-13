module Integrations
  module Plex
    class PlaybackReporter
      COMPLETION_THRESHOLD = 0.9

      def initialize(base_url:, request:, access_token:)
        @base_url = base_url
        @request = request
        @access_token = access_token
      end

      def report(event:, item_id:, position_ticks:, paused:, duration_ticks:)
        duration = milliseconds(duration_ticks)
        request.call(:get, "#{base_url}/:/timeline", params: timeline_parameters(event, item_id, position_ticks, paused, duration), access_token: access_token)
        scrobble(item_id) if event == "stopped" && completed?(position_ticks, duration_ticks)
      end

      def reset(item_id)
        request.call(:get, "#{base_url}/:/unscrobble", params: { key: item_id, identifier: "com.plexapp.plugins.library" }, access_token: access_token)
      end

      private

      attr_reader :base_url, :request, :access_token

      def timeline_parameters(event, item_id, position_ticks, paused, duration)
        {
          ratingKey: item_id,
          key: "/library/metadata/#{item_id}",
          state: state_for(event, paused),
          time: milliseconds(position_ticks),
          duration:,
          type: "music",
          identifier: "com.plexapp.plugins.library"
        }
      end

      def state_for(event, paused)
        return "stopped" if event == "stopped"

        paused ? "paused" : "playing"
      end

      def completed?(position_ticks, duration_ticks)
        duration_ticks.to_i.positive? && position_ticks.to_i >= duration_ticks.to_i * COMPLETION_THRESHOLD
      end

      def scrobble(item_id)
        request.call(:get, "#{base_url}/:/scrobble", params: { key: item_id, identifier: "com.plexapp.plugins.library" }, access_token: access_token)
      end

      def milliseconds(ticks)
        ticks.to_i / 10_000
      end
    end
  end
end
