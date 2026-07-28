require Rails.root.join("lib/sonzra/encryption_keys")

Rails.application.configure do
  root_secret = ENV["SONZRA_SECRET_KEY"].presence
  encryption_key = lambda do |name|
    ENV["ACTIVE_RECORD_ENCRYPTION_#{name.upcase}"].presence ||
      (Sonzra::EncryptionKeys.for(name, root_secret: root_secret) if root_secret) ||
      Rails.application.credentials.dig(:active_record_encryption, name)
  end

  config.active_record.encryption.primary_key = encryption_key.call(:primary_key)
  config.active_record.encryption.deterministic_key = encryption_key.call(:deterministic_key)
  config.active_record.encryption.key_derivation_salt = encryption_key.call(:key_derivation_salt)
end
