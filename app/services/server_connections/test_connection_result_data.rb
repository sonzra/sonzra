module ServerConnections
  TestConnectionResultData = Data.define(:success, :message) do
    def success?
      success
    end
  end
end
