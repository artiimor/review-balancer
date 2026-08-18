# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SsrfProtection do
  describe '.safe?' do
    it 'rejects non-https schemes' do
      expect(described_class.safe?('http://gitlab.com')).to be false
    end

    it 'rejects an invalid URL' do
      expect(described_class.safe?('not a url')).to be false
    end

    it 'rejects a URL without a host' do
      expect(described_class.safe?('https:///path')).to be false
    end

    it 'rejects loopback addresses' do
      expect(described_class.safe?('https://127.0.0.1')).to be false
      expect(described_class.safe?('https://[::1]')).to be false
    end

    it 'rejects private network addresses' do
      expect(described_class.safe?('https://10.0.0.5')).to be false
      expect(described_class.safe?('https://192.168.1.1')).to be false
      expect(described_class.safe?('https://172.16.0.1')).to be false
    end

    it 'rejects the link-local metadata address' do
      expect(described_class.safe?('https://169.254.169.254')).to be false
    end

    it 'allows a public address' do
      expect(described_class.safe?('https://8.8.8.8')).to be true
    end

    it 'allows a host that cannot be resolved, since it cannot be reached either way' do
      allow(Resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError)

      expect(described_class.safe?('https://unresolvable.invalid')).to be true
    end

    it 'allows a private address for an explicitly allowlisted host' do
      stub_const('SsrfProtection::ALLOWED_HOSTS', ['git.internal'])
      allow(Resolv).to receive(:getaddresses).with('git.internal').and_return(['172.21.10.204'])

      expect(described_class.safe?('https://git.internal')).to be true
    end
  end

  describe '.resolve_pinned_ip!' do
    it 'returns the IP for a public IP-literal URL' do
      expect(described_class.resolve_pinned_ip!('https://8.8.8.8')).to eq('8.8.8.8')
    end

    it 'raises for a non-https scheme' do
      expect { described_class.resolve_pinned_ip!('http://8.8.8.8') }.to raise_error(SsrfProtection::UnsafeUrlError)
    end

    it 'raises for a loopback address' do
      expect { described_class.resolve_pinned_ip!('https://127.0.0.1') }.to raise_error(SsrfProtection::UnsafeUrlError)
    end

    it 'raises when the host cannot be resolved, unlike .safe? which tolerates it' do
      allow(Resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError)

      expect { described_class.resolve_pinned_ip!('https://unresolvable.invalid') }
        .to raise_error(SsrfProtection::UnsafeUrlError, 'could not resolve host')
    end
  end
end
