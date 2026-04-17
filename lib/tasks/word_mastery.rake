namespace :word_mastery do
  desc "Backfill UserLexemeState and coverage records from existing ReviewLogs (FT-031)"
  task backfill: :environment do
    correct_logs = ReviewLog.where(correct: true).order(:reviewed_at)
    total = correct_logs.count
    processed = 0
    errors = 0

    puts "Backfilling word mastery state from #{total} correct review logs..."

    correct_logs.find_each do |review_log|
      next if LexemeReviewContribution.exists?(review_log_id: review_log.id)

      ActiveRecord::Base.transaction do
        WordMastery::RecordCoverage.call(review_log: review_log, now: review_log.reviewed_at)
      end
      processed += 1
      puts "  #{processed}/#{total} (#{(processed.to_f / total * 100).round(1)}%)" if (processed % 100).zero?
    rescue StandardError => e
      errors += 1
      warn "  ERROR log=#{review_log.id}: #{e.message}"
    end

    puts "Done: #{processed} processed, #{errors} errors"
  end
end
