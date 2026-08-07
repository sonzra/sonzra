module ServerConnections
  FetchLyricsResultData = Data.define(:lines, :access_token, :available, :synchronized, :message) do
    def success?
      message.nil?
    end
  end
end
