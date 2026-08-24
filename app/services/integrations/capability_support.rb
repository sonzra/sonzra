module Integrations
  module CapabilitySupport
    def supports?(capability)
      capabilities.include?(capability)
    end

    def capabilities
      self.class.const_defined?(:CAPABILITIES) ? self.class::CAPABILITIES : [].freeze
    end
  end
end
