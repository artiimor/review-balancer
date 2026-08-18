# frozen_string_literal: true

Rack::Attack.cache.store = if Rails.env.test?
                             ActiveSupport::Cache::MemoryStore.new
                           else
                             ActiveSupport::Cache::RedisCacheStore.new(
                               url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
                             )
                           end

Rack::Attack.throttle('webhooks/ip', limit: 30, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/webhooks/')
end

Rack::Attack.blocklist('webhooks/oversized-body') do |req|
  req.path.start_with?('/webhooks/') && req.content_length.to_i > 5.megabytes
end

Rack::Attack.enabled = !Rails.env.test?
