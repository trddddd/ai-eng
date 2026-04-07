class AddMasteredAtToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :mastered_at, :datetime, null: true
  end
end
