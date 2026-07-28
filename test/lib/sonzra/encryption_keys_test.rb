require "test_helper"
require Rails.root.join("lib/sonzra/encryption_keys")

class Sonzra::EncryptionKeysTest < ActiveSupport::TestCase
  test "derives stable, purpose-specific keys from one root secret" do
    root_secret = "deployment-root-secret"

    primary_key = Sonzra::EncryptionKeys.for(:primary_key, root_secret: root_secret)

    assert_equal primary_key, Sonzra::EncryptionKeys.for(:primary_key, root_secret: root_secret)
    assert_not_equal primary_key, Sonzra::EncryptionKeys.for(:deterministic_key, root_secret: root_secret)
  end
end
