require "rails_helper"

RSpec.describe ContentBootstrap::AssignFallbackSenses, type: :operation do
  describe ".call" do
    let!(:language) { create(:language, code: "en", name: "English") }

    def create_lexeme(headword, pos)
      create(:lexeme, headword:, pos:, language:)
    end

    context "with lexemes that have no senses" do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let!(:noun_lexeme) { create_lexeme("thing", "noun") }
      let!(:verb_lexeme) { create_lexeme("do", "verb") }
      let!(:adj_lexeme) { create_lexeme("fast", "adjective") }
      let!(:adv_lexeme) { create_lexeme("quickly", "adverb") }
      let!(:nil_pos_lexeme) { create_lexeme("xyz", nil) }

      it "creates fallback senses for all lexemes without senses" do
        expect { described_class.call }.to change(Sense, :count).by(5)
      end

      it "creates fallback sense with correct definition for noun" do
        described_class.call
        sense = noun_lexeme.reload.senses.first
        expect(sense.definition).to eq("The word 'thing' (noun)")
        expect(sense.pos).to eq("noun")
        expect(sense.source).to eq("fallback")
        expect(sense.external_id).to be_nil
        expect(sense.sense_rank).to eq(1)
      end

      it "creates fallback sense with correct definition for verb" do
        described_class.call
        sense = verb_lexeme.reload.senses.first
        expect(sense.definition).to eq("The action of 'do' (verb)")
      end

      it "creates fallback sense with correct definition for adjective" do
        described_class.call
        sense = adj_lexeme.reload.senses.first
        expect(sense.definition).to eq("The quality of being 'fast' (adjective)")
      end

      it "creates fallback sense with correct definition for adverb" do
        described_class.call
        sense = adv_lexeme.reload.senses.first
        expect(sense.definition).to eq("The manner of 'quickly' (adverb)")
      end

      it "creates fallback sense for lexeme with nil POS" do
        described_class.call
        sense = nil_pos_lexeme.reload.senses.first
        expect(sense.definition).to eq("The word 'xyz'")
        expect(sense.pos).to eq("unknown")
      end
    end

    context "with lexemes that already have senses" do
      let!(:existing_lexeme) { create_lexeme("run", "verb") }

      before do
        create(:sense, lexeme: existing_lexeme, definition: "Existing sense", pos: "verb")
      end

      it "skips lexemes with existing senses" do
        expect { described_class.call }.not_to(change(Sense, :count))
      end

      it "does not create duplicate senses" do
        described_class.call
        expect(existing_lexeme.senses.count).to eq(1)
        expect(existing_lexeme.senses.first.source).not_to eq("fallback")
      end
    end

    context "when run multiple times" do
      before { create_lexeme("newword", "noun") }

      it "does not create duplicate fallback senses on second run" do
        described_class.call
        first_count = Sense.count

        described_class.call

        expect(Sense.count).to eq(first_count)
      end
    end

    context "with mixed lexemes (some with senses, some without)" do
      let!(:with_sense) { create_lexeme("run", "verb") }
      let!(:without_sense) { create_lexeme("thing", "noun") }

      before do
        create(:sense, lexeme: with_sense, definition: "Existing sense", pos: "verb")
      end

      it "only creates fallback senses for lexemes without senses" do
        expect { described_class.call }.to change(Sense, :count).by(1)
        expect(with_sense.reload.senses.count).to eq(1)
        expect(with_sense.senses.first.source).not_to eq("fallback")
        expect(without_sense.reload.senses.count).to eq(1)
        expect(without_sense.senses.first.source).to eq("fallback")
      end
    end

    context "when logging" do
      before do
        create_lexeme("word1", "noun")
        create_lexeme("word2", "verb")
      end

      it "logs summary with fallback count" do
        described_class.call
        expect(Sense.count).to eq(2)
      end
    end
  end
end
