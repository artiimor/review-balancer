# frozen_string_literal: true

# GitHub firma cada payload de webhook con HMAC-SHA256 usando el secreto
# configurado, y lo manda en la cabecera X-Hub-Signature-256 como
# "sha256=<hex digest>". Si no verificamos esto, cualquiera que encuentre
# la URL del webhook podría enviarnos payloads falsos.
class GithubSignatureVerifier
  def self.valid?(payload_body:, signature_header:, secret:)
    return false if signature_header.blank?

    expected = 'sha256=' + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'), secret, payload_body
    )

    # Comparación en tiempo constante para evitar timing attacks.
    ActiveSupport::SecurityUtils.secure_compare(expected, signature_header)
  end
end
