module Integrations
  module Jellyfin
    AudioStreamResponseData = Data.define(:body, :accept_ranges, :content_type, :content_length, :content_range, :status)
  end
end
