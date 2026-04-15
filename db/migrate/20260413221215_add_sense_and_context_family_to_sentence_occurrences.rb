class AddSenseAndContextFamilyToSentenceOccurrences < ActiveRecord::Migration[8.1]
  def change
    add_reference :sentence_occurrences, :sense, type: :uuid, null: true, foreign_key: { on_delete: :restrict }, index: true
    add_reference :sentence_occurrences, :context_family, type: :uuid, null: true, foreign_key: { on_delete: :restrict }, index: true
  end
end


