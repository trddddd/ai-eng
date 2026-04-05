class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards, id: false do |t|
      t.column :id, :uuid, primary_key: true, default: -> { "uuidv7()" }
      t.references :user, type: :bigint, null: false,
                          foreign_key: { on_delete: :cascade }, index: false
      t.references :sentence_occurrence, type: :uuid, null: false,
                                         foreign_key: { on_delete: :restrict }, index: false
      t.datetime :due, null: false
      t.float :stability, null: false, default: 0.0
      t.float :difficulty, null: false, default: 0.0
      t.integer :elapsed_days, null: false, default: 0
      t.integer :scheduled_days, null: false, default: 0
      t.integer :reps, null: false, default: 0
      t.integer :lapses, null: false, default: 0
      t.integer :state, null: false, default: 0
      t.datetime :last_review
      t.timestamps null: false
    end

    add_index :cards, %i[user_id sentence_occurrence_id], unique: true
    add_index :cards, %i[user_id due]
    add_index :cards, %i[user_id state]
  end
end
