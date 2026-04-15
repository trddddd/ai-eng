class AddTatoebaIdToSentences < ActiveRecord::Migration[8.1]
  def change
    add_column :sentences, :tatoeba_id, :integer
    add_index :sentences, :tatoeba_id
  end
end
