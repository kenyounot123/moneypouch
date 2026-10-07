Rails.application.configure do
  if credentials.active_record_encryption.blank?
    config.active_record.encryption.primary_key = key_generator.generate_key("active_record_encryption/primary_key", 32).unpack1("H*")
    config.active_record.encryption.deterministic_key = key_generator.generate_key("active_record_encryption/deterministic_key", 32).unpack1("H*")
    config.active_record.encryption.key_derivation_salt = key_generator.generate_key("active_record_encryption/key_derivation_salt", 32).unpack1("H*")
  end
end
