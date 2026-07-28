require "openssl"

module Sonzra
  class EncryptionKeys
    PURPOSE = "sonzra.active_record_encryption".freeze

    def self.for(name, root_secret:)
      OpenSSL::HMAC.hexdigest("SHA256", root_secret, "#{PURPOSE}.#{name}")
    end
  end
end
