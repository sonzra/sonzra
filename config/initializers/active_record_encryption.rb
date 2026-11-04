require Rails.root.join("lib/sonzra/encryption_keys")

Rails.application.configure do
  root_secret = ENV["SONZRA_SECRET_KEY"].presence
  dev_fallback_keys = {
    primary_key: "9a70b7d5e49390f6f7e6d8b4a9012c3d",
    deterministic_key: "cf63a9d772e4b0086e5a4c3d2f1908ab",
    key_derivation_salt: "7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f"
  }

  encryption_key = lambda do |name|
    ENV["ACTIVE_RECORD_ENCRYPTION_#{name.upcase}"].presence ||
      (Sonzra::EncryptionKeys.for(name, root_secret: root_secret) if root_secret) ||
      Rails.application.credentials.dig(:active_record_encryption, name) ||
      (dev_fallback_keys[name] if Rails.env.development? || Rails.env.test?)
  end

  config.active_record.encryption.primary_key = encryption_key.call(:primary_key)
  config.active_record.encryption.deterministic_key = encryption_key.call(:deterministic_key)
  config.active_record.encryption.key_derivation_salt = encryption_key.call(:key_derivation_salt)
end
