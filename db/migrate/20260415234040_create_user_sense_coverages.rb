class CreateUserSenseCoverages < ActiveRecord::Migration[8.1]
  def change
    create_table :user_sense_coverages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :bigint, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :sense_id, null: false
      t.datetime :first_correct_at, null: false

      t.timestamps
    end

    add_foreign_key :user_sense_coverages, :senses, on_delete: :cascade
    add_index :user_sense_coverages, %i[user_id sense_id], unique: true
  end
end
