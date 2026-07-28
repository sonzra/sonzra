Rails.application.configure do
  encryption_key = lambda do |name|
    ENV.fetch("ACTIVE_RECORD_ENCRYPTION_#{name.upcase}") do
      Rails.application.credentials.dig(:active_record_encryption, name)
    end
  end

  config.active_record.encryption.primary_key = encryption_key.call(:primary_key)
  config.active_record.encryption.deterministic_key = encryption_key.call(:deterministic_key)
  config.active_record.encryption.key_derivation_salt = encryption_key.call(:key_derivation_salt)
end
