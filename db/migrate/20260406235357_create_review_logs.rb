class CreateReviewLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :review_logs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :card_id, null: false
      t.integer :rating, null: false
      t.string :recall_quality, null: false
      t.boolean :correct, null: false
      t.string :answer_text
      t.float :answer_accuracy
      t.integer :elapsed_ms
      t.integer :attempts, null: false, default: 1
      t.integer :backspace_count
      t.datetime :reviewed_at, null: false

      t.timestamps
    end

    add_index :review_logs, %i[card_id reviewed_at]
    add_foreign_key :review_logs, :cards, on_delete: :cascade
  end
end
