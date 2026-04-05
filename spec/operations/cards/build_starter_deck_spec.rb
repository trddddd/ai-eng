require "rails_helper"

RSpec.describe Cards::BuildStarterDeck do
  let(:en) { create(:language, code: "en", name: "English") }
  let(:ru) { create(:language, code: "ru", name: "Russian") }
  let(:user) { create(:user) }

  def make_a1_occurrence(headword: nil)
    headword ||= "word#{SecureRandom.hex(4)}"
    lexeme = create(:lexeme, language: en, cefr_level: "a1", headword: headword)
    sentence = create(:sentence, language: en, text: "I #{headword} something.")
    create(:sentence_translation, sentence: sentence, target_language: ru, text: "Перевод")
    create(:sentence_occurrence, sentence: sentence, lexeme: lexeme, form: headword)
  end

  describe ".call" do
    context "with A1 lexemes having Russian translations" do
      it "creates cards for the user" do
        make_a1_occurrence
        expect { described_class.call(user) }.to change { user.cards.count }.by(1)
      end

      it "sets due to current time" do
        freeze_time do
          make_a1_occurrence
          described_class.call(user)
          expect(user.cards.first.due).to be_within(1.second).of(Time.current)
        end
      end

      it "sets state to NEW" do
        make_a1_occurrence
        described_class.call(user)
        expect(user.cards.first.state).to eq(Card::STATE_NEW)
      end

      it "sets FSRS fields to defaults" do
        make_a1_occurrence
        described_class.call(user)
        card = user.cards.first
        expect(card).to have_attributes(
          stability: 0.0,
          difficulty: 0.0,
          elapsed_days: 0,
          scheduled_days: 0,
          reps: 0,
          lapses: 0,
          last_review: nil
        )
      end

      it "creates at most 50 cards" do
        55.times { make_a1_occurrence }
        described_class.call(user)
        expect(user.cards.count).to eq(50)
      end

      it "creates one card per lexeme" do
        lexeme = create(:lexeme, language: en, cefr_level: "a1", headword: "run")
        2.times do |i|
          sentence = create(:sentence, language: en, text: "She run#{i} fast.")
          create(:sentence_translation, sentence: sentence, target_language: ru, text: "Перевод")
          create(:sentence_occurrence, sentence: sentence, lexeme: lexeme, form: "run")
        end

        described_class.call(user)
        expect(user.cards.count).to eq(1)
      end
    end

    context "with no A1 lexemes" do
      it "creates no cards" do
        create(:lexeme, language: en, cefr_level: "b1")
        expect { described_class.call(user) }.not_to(change { user.cards.count })
      end
    end

    context "with A1 lexemes but no Russian translations" do
      it "creates no cards" do
        lexeme = create(:lexeme, language: en, cefr_level: "a1")
        sentence = create(:sentence, language: en)
        create(:sentence_occurrence, sentence: sentence, lexeme: lexeme)

        expect { described_class.call(user) }.not_to(change { user.cards.count })
      end
    end

    context "when called twice for the same user" do
      it "does not create duplicate cards" do
        make_a1_occurrence
        described_class.call(user)
        expect { described_class.call(user) }.not_to(change { user.cards.count })
      end
    end
  end
end
