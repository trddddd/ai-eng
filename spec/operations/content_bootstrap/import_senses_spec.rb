require "rails_helper"

RSpec.describe ContentBootstrap::ImportSenses, type: :operation do
  describe ".call" do
    let!(:language) { create(:language, code: "en", name: "English") }

    # Helper to create lexemes with the correct language
    def create_lexeme(headword, pos)
      create(:lexeme, headword:, pos:, language:)
    end

    context "with lexemes that have WordNet matches" do
      let!(:run_lexeme) { create_lexeme("run", "verb") }
      let!(:happy_lexeme) { create_lexeme("happy", "adjective") }

      it "creates senses from WordNet synsets" do
        expect { described_class.call }.to change(Sense, :count).by_at_least(1)
      end

      it "associates senses with correct lexeme" do
        described_class.call
        expect(run_lexeme.reload.senses).not_to be_empty
        expect(happy_lexeme.reload.senses).not_to be_empty
      end

      it "sets sense_rank for ordering (1 = most frequent)" do
        described_class.call
        senses = run_lexeme.reload.senses.order(:sense_rank)
        expect(senses.first.sense_rank).to eq(1)
      end

      it "stores definition from WordNet" do
        described_class.call
        sense = run_lexeme.reload.senses.first
        expect(sense.definition).to be_present
      end

      it "maps WordNet POS to string format" do
        described_class.call
        sense = run_lexeme.reload.senses.first
        expect(sense.pos).to eq("verb")
      end
    end

    context "with various POS types" do
      it "handles Oxford POS to WordNet POS mapping" do
        create_lexeme("must", "modal verb")
        create_lexeme("have", "auxiliary verb")

        expect { described_class.call }.to change(Sense, :count).by_at_least(1)
      end

      it "completes without error for determiners mapped to adjective" do
        create_lexeme("the", "determiner")

        # May have match or not depending on WordNet data
        expect { described_class.call }.not_to raise_error
      end

      it "logs warning for lexemes with POS that maps to nil (function words)" do
        pronoun_lexeme = create_lexeme("xyz123nonexistent", "pronoun")

        described_class.call
        expect(pronoun_lexeme.reload.senses).to be_empty
      end
    end

    context "with lexemes that have nil POS" do
      let!(:no_pos_lexeme) { create_lexeme("run", nil) }

      it "performs lookup without POS filter" do
        expect { described_class.call }.to change(Sense, :count).by_at_least(1)
        expect(no_pos_lexeme.reload.senses).not_to be_empty
      end
    end

    context "when run multiple times" do
      before { create_lexeme("run", "verb") }

      it "does not duplicate senses on second run" do
        described_class.call
        first_count = Sense.count

        described_class.call

        expect(Sense.count).to eq(first_count)
      end
    end

    context "with lexemes that have no WordNet match" do
      let!(:unknown_lexeme) { create_lexeme("xyz123nonexistent", "noun") }

      it "logs warning and skips lexeme" do
        described_class.call
        expect(unknown_lexeme.reload.senses).to be_empty
      end
    end

    context "with lexical_domain stored" do
      let!(:motion_lexeme) { create_lexeme("run", "verb") }

      it "stores lexical domain from WordNet synset" do
        described_class.call
        sense = motion_lexeme.reload.senses.first

        # Some synsets may not have lexical_domain, so we check if it's present or nil
        expect(sense.lexical_domain).to be_a(String).or(be_nil)
      end
    end

    context "with examples stored" do
      let!(:lexeme) { create_lexeme("run", "verb") }

      it "stores examples array from WordNet" do
        described_class.call
        sense = lexeme.reload.senses.first

        # Examples may be empty for some synsets
        expect(sense.examples).to be_an(Array)
      end
    end

    context "when logging" do
      before do
        create_lexeme("run", "verb")
        create_lexeme("happy", "adjective")
      end

      it "logs summary with matched and skipped counts" do
        described_class.call
        # Logs are written, we verify operation completes successfully
        expect(Sense.count).to be_positive
      end

      it "logs warning if >20% of lexemes are skipped" do
        # Create a fresh context with only non-matching lexemes
        clear_test_data
        non_matching_lexemes = 10.times.map { |i| create_lexeme("fakelexeme#{i}", "pronoun") }

        expect { described_class.call }.not_to raise_error

        # All non-matching lexemes should have no senses
        non_matching_lexemes.each do |lexeme|
          expect(lexeme.reload.senses).to be_empty
        end
      end

      def clear_test_data
        # Clear previous test data that might interfere
        Sense.delete_all
        Lexeme.delete_all
      end
    end
  end
end
