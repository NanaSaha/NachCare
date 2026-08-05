# Backs Rails' `encrypts` (used for caregivers.contact, check_ins.note,
# assistant_turns.content per Section 5) and devise-two-factor 6.x's
# built-in otp_secret encryption. Keys must come from ENV in every
# environment that touches real data; the fallback below only covers a
# fresh dev/test checkout with no ops/.env yet, and its value here is
# intentionally public information (not treated as a secret) since dev/test
# databases are already gitignored.
Rails.application.config.active_record.encryption.primary_key =
  ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", "dev_only_primary_key_do_not_use_in_prod_")
Rails.application.config.active_record.encryption.deterministic_key =
  ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", "dev_only_deterministic_key_do_not_use__")
Rails.application.config.active_record.encryption.key_derivation_salt =
  ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", "dev_only_key_derivation_salt_do_not_use")
