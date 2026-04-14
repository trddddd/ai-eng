class AddNotNullConstraintsToSentenceOccurrences < ActiveRecord::Migration[8.1]
  # rubocop:disable Metrics/MethodLength
  def up
    # Verify all occurrences have sense_id before adding constraint
    null_senses = SentenceOccurrence.where(sense_id: nil).count
    if null_senses.positive?
      raise "Cannot add NOT NULL constraint: #{null_senses} sentence_occurrences have null sense_id. Run backfill first: bin/rails content_bootstrap:backfill_sense_data"
    end
    change_column_null :sentence_occurrences, :sense_id, false

    # Verify all occurrences have context_family_id before adding constraint
    null_families = SentenceOccurrence.where(context_family_id: nil).count
    if null_families.positive?
      raise "Cannot add NOT NULL constraint: #{null_families} sentence_occurrences have null context_family_id. Run backfill first: bin/rails content_bootstrap:backfill_sense_data"
    end
    change_column_null :sentence_occurrences, :context_family_id, false
  end
  # rubocop:enable Metrics/MethodLength

  def down
    change_column_null :sentence_occurrences, :sense_id, true
    change_column_null :sentence_occurrences, :context_family_id, true
  end
end

