class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.bigint :site_ref, null: false
      t.string :role, null: false
      t.string :language, null: false, default: "en"

      # Devise :database_authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      # Devise :recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # Devise :rememberable
      t.datetime :remember_created_at

      # Devise :trackable
      t.integer  :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      # devise-two-factor (TOTP MFA)
      t.text    :encrypted_otp_secret
      t.string  :encrypted_otp_secret_iv
      t.string  :encrypted_otp_secret_salt
      t.integer :consumed_timestep
      t.boolean :otp_required_for_login, null: false, default: false

      # devise-jwt, JTIMatcher revocation strategy
      t.string :jti, null: false

      t.timestamps null: false
    end

    add_foreign_key :users, :sites, column: :site_ref
    add_index :users, :site_ref
    add_index :users, :role
    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :jti, unique: true

    add_check_constraint :users,
      "role IN ('ward_nurse','nurse','physician','site_admin','sysadmin','analyst')",
      name: "users_role_check"
  end
end
