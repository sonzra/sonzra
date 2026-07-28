ENV["RAILS_ENV"] ||= "test"
ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] ||= "9a70b7d5e49390f6f7e6d8b4a9012c3d"
ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] ||= "cf63a9d772e4b0086e5a4c3d2f1908ab"
ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
end
