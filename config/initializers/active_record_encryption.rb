# frozen_string_literal: true

# El secreto del webhook (Repository#webhook_secret) se cifra en reposo con
# Active Record Encryption. En vez de credentials.yml.enc (que exige commitear
# config/master.key), las claves se leen de variables de entorno para encajar
# bien con Docker/12-factor. Generarlas con:
#   bin/rails db:encryption:init
Rails.application.configure do
  config.active_record.encryption.primary_key = ENV['AR_ENCRYPTION_PRIMARY_KEY']
  config.active_record.encryption.deterministic_key = ENV['AR_ENCRYPTION_DETERMINISTIC_KEY']
  config.active_record.encryption.key_derivation_salt = ENV['AR_ENCRYPTION_KEY_DERIVATION_SALT']
end
