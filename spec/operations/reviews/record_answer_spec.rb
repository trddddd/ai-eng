require "rails_helper"

RSpec.describe Reviews::RecordAnswer do
  let(:card) { create(:card, due: 1.hour.ago) }

  describe ".call" do
    context "with correct answer on first attempt" do
      it "creates a ReviewLog" do
        expect do
          described_class.call(card: card, correct: true, answer_text: card.form, elapsed_ms: 5_000)
        end.to change(ReviewLog, :count).by(1)
      end

      it "sets correct and rating on the log" do
        log = described_class.call(card: card, correct: true, answer_text: card.form, elapsed_ms: 5_000)
        expect(log).to have_attributes(correct: true, rating: ReviewLog::RATING_GOOD)
      end

      it "schedules the card" do
        original_due = card.due
        described_class.call(card: card, correct: true, answer_text: card.form)
        expect(card.reload.due).not_to eq(original_due)
      end
    end

    context "with near-miss (typo, one char off)" do
      it "assigns Hard rating instead of Again" do
        # card.form is "word"; "wrod" has distance 2 from "word" → accuracy 0.5 → no_recall
        # use a form where single-char typo gives accuracy >= 0.7
        # "running" → "runnig" (distance 1, max_len 7, accuracy 0.86)
        so = create(:sentence_occurrence, form: "running")
        typo_card = create(:card, due: 1.hour.ago, sentence_occurrence: so)
        log = described_class.call(card: typo_card, correct: false, answer_text: "runnig")
        expect(log.rating).to eq(ReviewLog::RATING_HARD)
        expect(log.recall_quality).to eq("near_miss")
      end
    end

    context "with wrong answer (completely different word)" do
      it "assigns Again rating" do
        log = described_class.call(card: card, correct: false, answer_text: "xyz")
        expect(log.rating).to eq(ReviewLog::RATING_AGAIN)
        expect(log.recall_quality).to eq("no_recall")
      end
    end

    context "with multiple attempts (retry)" do
      it "correct=false on first attempt means no_recall regardless of attempts count" do
        log = described_class.call(card: card, correct: false, answer_text: "xyz", attempts: 3)
        expect(log.rating).to eq(ReviewLog::RATING_AGAIN)
        expect(log.attempts).to eq(3)
      end
    end

    context "with backspace_count and attempts" do
      it "saves backspace_count and attempts but does not affect rating" do
        log = described_class.call(
          card: card, correct: true, answer_text: card.form,
          elapsed_ms: 5_000, attempts: 2, backspace_count: 5
        )
        expect(log.backspace_count).to eq(5)
        expect(log.attempts).to eq(2)
        expect(log.rating).to eq(ReviewLog::RATING_GOOD)
      end
    end

    context "when called twice on the same card" do
      it "creates two ReviewLogs" do
        described_class.call(card: card, correct: true, answer_text: card.form)
        expect do
          described_class.call(card: card, correct: true, answer_text: card.form)
        end.to change(ReviewLog, :count).by(1)
      end
    end

    it "rolls back if schedule! fails" do
      allow(card).to receive(:schedule!).and_raise(ActiveRecord::RecordInvalid)

      expect do
        described_class.call(card: card, correct: true, answer_text: card.form)
      rescue StandardError
        nil
      end.not_to change(ReviewLog, :count)
    end

    describe "word mastery integration (FT-034)" do
      it "calls WordMastery::RecordCoverage on correct answer" do
        allow(WordMastery::RecordCoverage).to receive(:call).and_call_original
        described_class.call(card: card, correct: true, answer_text: card.form)
        expect(WordMastery::RecordCoverage).to have_received(:call)
          .with(hash_including(:review_log))
      end

      it "does not call WordMastery::RecordCoverage on incorrect answer" do
        allow(WordMastery::RecordCoverage).to receive(:call)
        described_class.call(card: card, correct: false, answer_text: "xyz")
        expect(WordMastery::RecordCoverage).not_to have_received(:call)
      end

      it "updates UserLexemeState in the same transaction as ReviewLog" do
        expect do
          described_class.call(card: card, correct: true, answer_text: card.form)
        end.to change(ReviewLog, :count).by(1)
                                        .and change(UserLexemeState, :count).by(1)
                                                                            .and change(LexemeReviewContribution, :count).by(1)
      end

      it "rolls back ReviewLog and contribution if RecordCoverage raises" do
        allow(WordMastery::RecordCoverage).to receive(:call).and_raise(ActiveRecord::RecordInvalid)

        expect do
          described_class.call(card: card, correct: true, answer_text: card.form)
        rescue StandardError
          nil
        end.not_to change(ReviewLog, :count)

        expect(LexemeReviewContribution.count).to eq(0)
      end

      it "creates two ReviewLogs and two contributions when called twice" do
        described_class.call(card: card, correct: true, answer_text: card.form)
        expect do
          described_class.call(card: card, correct: true, answer_text: card.form)
        end.to change(ReviewLog, :count).by(1)
                                        .and change(LexemeReviewContribution, :count).by(1)
      end
    end
  end
end
