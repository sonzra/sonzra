require "json"
require "net/http"
require "uri"

module Integrations
  module Jellyfin
    class Client
      class AuthenticationError < StandardError; end
      class ConnectionError < StandardError; end

      def initialize(base_url:, username:, password:, http: Net::HTTP)
        @base_url = base_url
        @username = username
        @password = password
        @http = http
      end

      def authenticate
        response = http.start(
          endpoint.host,
          endpoint.port,
          use_ssl: endpoint.scheme == "https",
          open_timeout: 5,
          read_timeout: 10
        ) { |connection| connection.request(request) }

        raise AuthenticationError if response.code == "401"
        raise ConnectionError, "The server returned HTTP #{response.code}." unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body).fetch("User").fetch("Name")
      rescue JSON::ParserError, KeyError
        raise ConnectionError, "The server returned an unexpected response."
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach the server. Check the address and try again."
      rescue OpenSSL::SSL::SSLError
        raise ConnectionError, "Could not establish a secure connection to the server."
      end

      private

      attr_reader :base_url, :username, :password, :http

      def endpoint
        @endpoint ||= URI.parse("#{base_url}/Users/AuthenticateByName")
      end

      def request
        Net::HTTP::Post.new(
          endpoint,
          {
            "Content-Type" => "application/json",
            "X-Emby-Authorization" => authorization_header
          }
        ).tap { |post| post.body = { Username: username, Pw: password }.to_json }
      end

      def authorization_header
        'MediaBrowser Client="Sonzra", Device="Sonzra", DeviceId="sonzra-web", Version="1.0.0"'
      end
    end
  end
end
