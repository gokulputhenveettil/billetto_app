require "net/http"
require "uri"
require "json"

module Billetto
	class Client
		BASE_URL = "https://billetto.dk/api/v3/public/events"

		def initialize(api_keypair:)
			@api_keypair = api_keypair
		end

		def fetch_events(limit: 100, next_url: nil)
			url = next_url || "#{BASE_URL}?limit=#{limit}"
			uri = URI.parse(url)
			request = Net::HTTP::Get.new(uri)
			request["Api-Keypair"] = @api_keypair
			request["Accept"] = "application/json"

			response = Net::HTTP.start(
				uri.host,
				uri.port,
				use_ssl: uri.scheme == "https",
				open_timeout: 10,
				read_timeout: 30
			) do |http|
					http.request(request)
			end

			unless response.is_a?(Net::HTTPSuccess)
				raise "Billetto API request failed: #{response.code} #{response.message}"
			end

			JSON.parse(response.body)
		rescue JSON::ParserError => e
			raise "Invalid JSON returned by Billetto API: #{e.message}"
		rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
			raise "Unable to connect to Billetto API: #{e.message}"
		end
	end
end
