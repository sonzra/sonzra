module ServerConnections
  class FetchLyrics
    URL_LIKE_LINE = %r{(?:https?://|www\.|(?:[a-z0-9-]+\.)+(?:com|net|org|io|co|tv)\b)}i

    def initialize(server_connection, item_id, remote_user_id: nil, client: nil)
      @server_connection = server_connection
      @item_id = item_id
      @remote_user_id = remote_user_id
      @client = client
    end

    def call
      response = client.lyrics(@item_id)
      lines = normalize_lines(response.lines)
      available = response.available && lines.any? && !unusable?(lines)

      FetchLyricsResultData.new(
        lines: available ? lines : [],
        access_token: response.access_token,
        available: available,
        synchronized: available && lines.all? { |line| line[:start].present? },
        message: nil
      )
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      FetchLyricsResultData.new(lines: [], access_token: nil, available: false, synchronized: false, message: error.message.presence || "Could not load lyrics.")
    end

    private

    def client
      @client ||= Integrations::Client.for(@server_connection, remote_user_id: @remote_user_id)
    end

    def normalize_lines(lines)
      Array(lines).filter_map do |line|
        text = line.fetch("Text", "").to_s.strip
        next if text.blank?

        { text: text, start: timestamp_for(line) }
      end
    end

    def timestamp_for(line)
      start = line["Start"]
      start.present? ? start.to_f / 10_000_000 : nil
    end

    def unusable?(lines)
      lines.one? && lines.first[:text].match?(URL_LIKE_LINE)
    end
  end
end
