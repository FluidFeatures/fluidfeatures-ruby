
require 'net/http'
require 'persistent_http'
require "pre_ruby192/uri" if RUBY_VERSION < "1.9.2"

require "fluidfeatures/app"

module FluidFeatures
  class Client

    attr_accessor :base_uri, :logger, :last_fetch_duration

    def initialize(base_uri, logger)

      @logger = logger
      @base_uri = base_uri

      @http = ::PersistentHTTP.new(
        :name         => 'fluidfeatures',
        :logger       => logger,
        :pool_size    => 10,
        :warn_timeout => 0.25,
        :force_retry  => true,
        :url          => base_uri
      )

      @last_fetch_duration = nil

    end

    def get(path, auth_token, url_params=nil)
      payload = nil

      uri = URI(@base_uri + path)
      url_path = uri.path
      if url_params
        uri.query = URI.encode_www_form( url_params )
        if uri.query
          url_path += "?" + uri.query
        end
      end

      begin
        request = Net::HTTP::Get.new url_path
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = auth_token
        fetch_start_time = Time.now
        response = @http.request request
        if response.is_a?(Net::HTTPSuccess)
          payload = JSON.parse(response.body)
          @last_fetch_duration = Time.now - fetch_start_time
        end
      rescue
        logger.error{"[FF] Request failed when getting #{path}"}
        raise
      end
      if not payload
        logger.error{"[FF] Empty response from #{path}"}
      end
      payload
    end

    def put(path, auth_token, payload)
      begin
        uri = URI(@base_uri + path)
        request = Net::HTTP::Put.new uri.path
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = auth_token
        request.body = JSON.dump(payload)
        response = @http.request uri, request
        unless response.is_a?(Net::HTTPSuccess)
          logger.error{"[FF] Request unsuccessful when putting #{path}"}
        end
      rescue Exception => err
        logger.error{"[FF] Request failed putting #{path} : #{err.message}"}
        raise
      end
    end

    def post(path, auth_token, payload)
      begin
        uri = URI(@base_uri + path)
        request = Net::HTTP::Post.new uri.path
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request['AUTHORIZATION'] = auth_token
        request.body = JSON.dump(payload)
        response = @http.request request
        unless response.is_a?(Net::HTTPSuccess)
          logger.error{"[FF] Request unsuccessful when posting #{path}"}
        end
      rescue Exception => err
        logger.error{"[FF] Request failed posting #{path} : #{err.message}"}
        raise
      end
    end

  end
end
