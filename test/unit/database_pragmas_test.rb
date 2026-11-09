require "test_helper"

class DatabasePragmasTest < ActiveSupport::TestCase
  test "sqlite connection has busy_timeout set to 5000" do
    result = ActiveRecord::Base.connection.execute("PRAGMA busy_timeout").first
    timeout = result.is_a?(Hash) ? result["timeout"] : result[0]
    assert_equal 5000, timeout
  end

  test "sqlite connection has foreign_keys enabled" do
    result = ActiveRecord::Base.connection.execute("PRAGMA foreign_keys").first
    foreign_keys = result.is_a?(Hash) ? result["foreign_keys"] : result[0]
    assert_equal 1, foreign_keys
  end

  test "sqlite connection has journal_mode set to wal" do
    result = ActiveRecord::Base.connection.execute("PRAGMA journal_mode").first
    journal_mode = result.is_a?(Hash) ? result["journal_mode"] : result[0]
    assert_equal "wal", journal_mode
  end
end
