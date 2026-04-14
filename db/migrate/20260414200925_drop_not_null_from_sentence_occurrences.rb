class DropNotNullFromSentenceOccurrences < ActiveRecord::Migration[8.1]
  # Phase 3 (NOT NULL constraints) is deferred until production backfill is confirmed.
  # ImportQuizword (deprecated) and other operations still create occurrences without
  # sense/context_family during the transition period. Phase 3 will be reapplied as a
  # separate migration after the backfill rake task completes in production.
  def change
    change_column_null :sentence_occurrences, :sense_id, true
    change_column_null :sentence_occurrences, :context_family_id, true
  end
end
