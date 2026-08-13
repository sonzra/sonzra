module Integrations
  module Plex
    class LyricsParser
      TIMESTAMP = /\[(?<minutes>\d{1,2}):(?<seconds>\d{2}(?:\.\d{1,3})?)\]/

      def self.call(text)
        new(text).call
      end

      def initialize(text)
        @text = text.to_s
      end

      def call
        text.each_line.filter_map do |line|
          timestamps = line.scan(TIMESTAMP)
          lyric = line.gsub(TIMESTAMP, "").strip
          next if lyric.blank? || lyric.start_with?("[")

          timestamps.any? ? timestamps.map { |minutes, seconds| timed_line(lyric, minutes, seconds) } : { "Text" => lyric }
        end.flatten
      end

      private

      attr_reader :text

      def timed_line(lyric, minutes, seconds)
        { "Text" => lyric, "Start" => ((minutes.to_i * 60) + seconds.to_f) * 10_000_000 }
      end
    end
  end
end
