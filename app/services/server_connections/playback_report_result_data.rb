module ServerConnections
  PlaybackReportResultData = Data.define(:access_token, :message) do
    def success?
      message.nil?
    end
  end
end
