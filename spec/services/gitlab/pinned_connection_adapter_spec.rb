# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gitlab::PinnedConnectionAdapter do
  it 'connects to the pinned IP while keeping the original host for the Host header and TLS SNI' do
    uri = URI.parse('https://gitlab.example.com/api/v4')
    adapter = described_class.new(uri, connection_adapter_options: { ssrf_safe_ip: '93.184.216.34' })

    http = adapter.connection

    expect(http.address).to eq('gitlab.example.com')
    expect(http.ipaddr).to eq('93.184.216.34')
    expect(http.use_ssl?).to be true
  end
end
