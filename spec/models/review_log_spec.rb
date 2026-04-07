require "rails_helper"

RSpec.describe ReviewLog, type: :model do
  let(:card) { create(:card) }

  describe "validations" do
    subject(:log) do
      build(:review_log, card: card)
    end

    it { expect(log).to be_valid }

    it "rejects invalid rating" do
      log.rating = 5
      expect(log).not_to be_valid
    end

    it "rejects invalid recall_quality" do
      log.recall_quality = "great"
      expect(log).not_to be_valid
    end

    it "requires correct to be boolean" do
      log.correct = nil
      expect(log).not_to be_valid
    end

    it "requires reviewed_at" do
      log.reviewed_at = nil
      expect(log).not_to be_valid
    end

    it "requires attempts > 0" do
      log.attempts = 0
      expect(log).not_to be_valid
    end

    it "rejects answer_accuracy outside 0..1" do
      log.answer_accuracy = 1.5
      expect(log).not_to be_valid
    end

    it "allows nil answer_accuracy" do
      log.answer_accuracy = nil
      expect(log).to be_valid
    end
  end

  describe ".compute_accuracy" do
    it "returns 1.0 for exact match" do
      expect(described_class.compute_accuracy("running", "running")).to eq(1.0)
    end

    it "returns 0.0 for blank answer" do
      expect(described_class.compute_accuracy("", "running")).to eq(0.0)
    end

    it "returns 0.0 for nil answer" do
      expect(described_class.compute_accuracy(nil, "running")).to eq(0.0)
    end

    it "computes near-miss accuracy for typo (runnig)" do
      result = described_class.compute_accuracy("runnig", "running")
      expect(result).to be_within(0.01).of(0.86)
    end

    it "computes low accuracy for completely different word (ran vs running)" do
      result = described_class.compute_accuracy("ran", "running")
      expect(result).to be_within(0.01).of(0.29)
    end

    it "is case-insensitive" do
      expect(described_class.compute_accuracy("Running", "running")).to eq(1.0)
    end
  end

  describe ".classify_recall" do
    context "when incorrect" do
      it "returns no_recall for accuracy < 0.7" do
        result = described_class.classify_recall(correct: false, answer_accuracy: 0.29)
        expect(result).to eq("no_recall")
      end

      it "returns near_miss for accuracy >= 0.7" do
        result = described_class.classify_recall(correct: false, answer_accuracy: 0.86)
        expect(result).to eq("near_miss")
      end

      it "returns no_recall when accuracy is nil" do
        result = described_class.classify_recall(correct: false, answer_accuracy: nil)
        expect(result).to eq("no_recall")
      end
    end

    context "when correct" do
      it "returns automatic_recall for fast response" do
        result = described_class.classify_recall(correct: true, elapsed_ms: 2_000)
        expect(result).to eq("automatic_recall")
      end

      it "returns successful_recall for normal response" do
        result = described_class.classify_recall(correct: true, elapsed_ms: 5_000)
        expect(result).to eq("successful_recall")
      end

      it "returns effortful_recall for slow response" do
        result = described_class.classify_recall(correct: true, elapsed_ms: 12_000)
        expect(result).to eq("effortful_recall")
      end

      it "returns successful_recall when elapsed_ms is nil" do
        result = described_class.classify_recall(correct: true, elapsed_ms: nil)
        expect(result).to eq("successful_recall")
      end
    end
  end

  describe ".compute_rating" do
    it "maps no_recall to Again (1)" do
      expect(described_class.compute_rating("no_recall")).to eq(ReviewLog::RATING_AGAIN)
    end

    it "maps near_miss to Hard (2)" do
      expect(described_class.compute_rating("near_miss")).to eq(ReviewLog::RATING_HARD)
    end

    it "maps effortful_recall to Hard (2)" do
      expect(described_class.compute_rating("effortful_recall")).to eq(ReviewLog::RATING_HARD)
    end

    it "maps successful_recall to Good (3)" do
      expect(described_class.compute_rating("successful_recall")).to eq(ReviewLog::RATING_GOOD)
    end

    it "maps automatic_recall to Easy (4)" do
      expect(described_class.compute_rating("automatic_recall")).to eq(ReviewLog::RATING_EASY)
    end
  end
end
