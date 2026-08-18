# frozen_string_literal: true

Rails.application.configure do
  config.active_record.encryption.primary_key = ENV.fetch('AR_ENCRYPTION_PRIMARY_KEY', nil)
  config.active_record.encryption.deterministic_key = ENV.fetch('AR_ENCRYPTION_DETERMINISTIC_KEY', nil)
  config.active_record.encryption.key_derivation_salt = ENV.fetch('AR_ENCRYPTION_KEY_DERIVATION_SALT', nil)
end
