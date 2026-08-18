# frozen_string_literal: true

require 'ipaddr'
require 'resolv'
require 'timeout'

class SsrfProtection
  class UnsafeUrlError < StandardError; end

  ALLOWED_SCHEMES = %w[https].freeze

  # RFC 1918/5735/4193 style ranges plus loopback/link-local/multicast, v4 and v6.
  BLOCKED_RANGES = [
    IPAddr.new('0.0.0.0/8'),
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('100.64.0.0/10'),
    IPAddr.new('127.0.0.0/8'),
    IPAddr.new('169.254.0.0/16'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('192.0.0.0/24'),
    IPAddr.new('192.0.2.0/24'),
    IPAddr.new('192.168.0.0/16'),
    IPAddr.new('198.18.0.0/15'),
    IPAddr.new('198.51.100.0/24'),
    IPAddr.new('203.0.113.0/24'),
    IPAddr.new('224.0.0.0/4'),
    IPAddr.new('240.0.0.0/4'),
    IPAddr.new('255.255.255.255/32'),
    IPAddr.new('::/128'),
    IPAddr.new('::1/128'),
    IPAddr.new('::ffff:0:0/96'),
    IPAddr.new('fc00::/7'),
    IPAddr.new('fe80::/10'),
    IPAddr.new('ff00::/8')
  ].freeze

  # Exact hostnames exempted from BLOCKED_RANGES, e.g. internal GitLab reachable only over VPN.
  ALLOWED_HOSTS = ENV.fetch('SSRF_ALLOWED_HOSTS', '').split(',').map(&:strip).reject(&:blank?).freeze

  def self.safe?(url)
    assert_safe!(url)
    true
  rescue UnsafeUrlError
    false
  end

  RESOLVE_TIMEOUT = 2 # seconds

  def self.assert_safe!(url)
    uri = validate_scheme_and_host(url)
    validate_addresses!(resolve(uri.host)) unless ALLOWED_HOSTS.include?(uri.host)
  end

  def self.resolve_pinned_ip!(url)
    uri = validate_scheme_and_host(url)
    addresses = resolve(uri.host)
    raise UnsafeUrlError, 'could not resolve host' if addresses.empty?

    validate_addresses!(addresses) unless ALLOWED_HOSTS.include?(uri.host)
    addresses.first
  end

  def self.validate_scheme_and_host(url)
    uri = parse(url)

    raise UnsafeUrlError, 'scheme must be https' unless ALLOWED_SCHEMES.include?(uri.scheme)
    raise UnsafeUrlError, 'missing host' if uri.host.blank?

    uri
  end
  private_class_method :validate_scheme_and_host

  def self.validate_addresses!(addresses)
    addresses.each do |address|
      ip = IPAddr.new(address)
      raise UnsafeUrlError, "#{address} is not a public address" if BLOCKED_RANGES.any? { |range| range.include?(ip) }
    end
  end
  private_class_method :validate_addresses!

  def self.parse(url)
    URI.parse(url.to_s)
  rescue URI::InvalidURIError
    raise UnsafeUrlError, 'invalid URL'
  end
  private_class_method :parse

  def self.resolve(host)
    return [host] if ip_literal?(host)

    Timeout.timeout(RESOLVE_TIMEOUT) { Resolv.getaddresses(host) }
  rescue Resolv::ResolvError, Timeout::Error, SocketError
    []
  end
  private_class_method :resolve

  def self.ip_literal?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::Error
    false
  end
  private_class_method :ip_literal?
end
