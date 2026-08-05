class CreateCheckInPhotos < ActiveRecord::Migration[7.2]
  def change
    create_table :check_in_photos do |t|
      t.bigint :check_in_ref, null: false

      t.timestamps
    end

    add_foreign_key :check_in_photos, :check_ins, column: :check_in_ref
    add_index :check_in_photos, :check_in_ref
  end
end
