# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'cgi'
require 'github/authorization'
require 'local_storage'

module Github
  class Api
    HOST_FILE = '~/.github-repos/host'.freeze

    def search_repos(query)
      path = "/search/repositories?q=#{escape(query)}"

      get(path)[:items]
    end

    class << self
      def configure_host(host)
        LocalStorage.new(HOST_FILE).put("#{host}/api/v3")
      end
    end

    private

    def host
      @host ||= (LocalStorage.new(HOST_FILE).get || 'https://api.github.com')
    end

    def escape(str)
      CGI.escape(str)
    end

    def get(path)
      req = Net::HTTP::Get.new(path)
      res = process_request(req)
      res.body
    end

    def process_request(req)
      uri = URI("#{host}#{req.path}")

      authorize(req)

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        yield(http) if block_given?
        http.request(req)
      end
      res.body = parse_body(res.body)
      res
    end

    def auth
      @auth ||= Authorization.authorize!
    end

    def authorize(request)
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/vnd.github.v3+json'
      request['User-Agent'] = 'Github Repos'
      request.basic_auth(auth.username, auth.token)
      request
    end

    def parse_body(body)
      return body if body.nil? || body.empty?

      JSON.parse(body, symbolize_names: true)
    end
  end
end
