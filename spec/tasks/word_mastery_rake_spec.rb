require "rails_helper"
require "rake"

RSpec.describe "word_mastery rake tasks" do # rubocop:disable RSpec/DescribeClass
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  before do
    Rake::Task["word_mastery:backfill"].reenable
  end

  describe "word_mastery:backfill" do
    it "creates coverage records from correct review logs" do
      user = create(:user)
      sense = create(:sense)
      occurrence = create(:sentence_occurrence, lexeme: sense.lexeme, sense: sense)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      create(:review_log, card: card, correct: true, reviewed_at: 1.day.ago)

      expect { Rake::Task["word_mastery:backfill"].invoke }
        .to change(UserLexemeState, :count).by(1)
        .and change(UserSenseCoverage, :count).by(1)
    end

    it "is idempotent — does not duplicate on second run" do
      user = create(:user)
      sense = create(:sense)
      occurrence = create(:sentence_occurrence, lexeme: sense.lexeme, sense: sense)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      create(:review_log, card: card, correct: true, reviewed_at: 1.day.ago)

      Rake::Task["word_mastery:backfill"].invoke
      Rake::Task["word_mastery:backfill"].reenable

      expect { Rake::Task["word_mastery:backfill"].invoke }
        .not_to change(UserSenseCoverage, :count)
    end

    it "skips incorrect review logs" do
      user = create(:user)
      sense = create(:sense)
      occurrence = create(:sentence_occurrence, lexeme: sense.lexeme, sense: sense)
      card = create(:card, user: user, sentence_occurrence: occurrence)
      create(:review_log, card: card, correct: false, reviewed_at: 1.day.ago)

      expect { Rake::Task["word_mastery:backfill"].invoke }
        .not_to change(UserLexemeState, :count)
    end
  end
end
