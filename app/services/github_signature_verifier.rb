# frozen_string_literal: true

class GithubSignatureVerifier
  def self.valid?(payload_body:, signature_header:, secret:)
    return false if signature_header.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'), secret, payload_body
    )}"

    # avoid timing attacks by using a constant-time comparison
    ActiveSupport::SecurityUtils.secure_compare(expected, signature_header)
  end
end
