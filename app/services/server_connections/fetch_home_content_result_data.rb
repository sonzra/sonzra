module ServerConnections
  FetchHomeContentResultData = Data.define(:content, :access_token, :message) do
    def success?
      message.nil?
    end
  end
end
