# frozen_string_literal: true

module Integrations
  AudioStreamResponseData = Data.define(:body, :accept_ranges, :content_type, :content_length, :content_range, :status)
end
