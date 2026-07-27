require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)
module Sonzra
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.generators.system_tests = nil
  end
end
