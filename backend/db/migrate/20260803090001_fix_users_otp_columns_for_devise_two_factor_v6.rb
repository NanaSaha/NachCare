class FixUsersOtpColumnsForDeviseTwoFactorV6 < ActiveRecord::Migration[7.2]
  # devise-two-factor 6.x replaced the old attr_encrypted-style triple
  # column (encrypted_otp_secret/_iv/_salt) with a single otp_secret column
  # encrypted via Rails' native Active Record encryption (config/
  # initializers/active_record_encryption.rb). The M0 migration for `users`
  # was written against the old (5.x) scheme before this was caught.
  def change
    remove_column :users, :encrypted_otp_secret, :text
    remove_column :users, :encrypted_otp_secret_iv, :string
    remove_column :users, :encrypted_otp_secret_salt, :string
    add_column :users, :otp_secret, :string
  end
end
