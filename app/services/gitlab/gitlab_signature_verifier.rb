# frozen_string_literal: true

module Gitlab
  class GitlabSignatureVerifier
    def self.valid?(token_header:, secret:)
      return false if token_header.blank?

      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(token_header), Digest::SHA256.hexdigest(secret.to_s)
      )
    end
  end
end
