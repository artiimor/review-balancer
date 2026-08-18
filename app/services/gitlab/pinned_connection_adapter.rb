# frozen_string_literal: true

module Gitlab
  # Avoid Net::Http Resolve the host again
  class PinnedConnectionAdapter < HTTParty::ConnectionAdapter
    def connection
      http = super
      http.ipaddr = options.fetch(:connection_adapter_options).fetch(:ssrf_safe_ip)
      http
    end
  end
end
