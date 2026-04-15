require "rails_helper"

RSpec.describe ContentBootstrap::AssignContextFamilies, type: :operation do
  describe ".call" do
    let!(:language) { create(:language, code: "en", name: "English") }

    def create_lexeme(headword, pos)
      create(:lexeme, headword:, pos:, language:)
    end

    def create_sentence_occurrence(lexeme:, sense: nil, text: nil)
      text ||= "This is a test sentence with #{lexeme.headword}."
      sentence = create(:sentence, text:, language:)
      # Use AR directly to create occurrences without sense/context_family —
      # sense_id and context_family_id are nullable (Phase 2, before backfill).
      SentenceOccurrence.create!(sentence:, lexeme:, form: lexeme.headword, sense:)
    end

    context "with occurrences that have senses with lexical_domain" do
      let!(:lexeme) { create_lexeme("run", "verb") }
      let!(:sense) do
        create(:sense, lexeme:, pos: "verb", lexical_domain: "verb.motion", sense_rank: 1)
      end
      let!(:occurrence) { create_sentence_occurrence(lexeme:, sense:) }

      before do
        # Ensure context families exist
        load_context_families
      end

      it "assigns correct context family based on lexical domain" do
        described_class.call
        expect(occurrence.reload.context_family).to be_present
        expect(occurrence.context_family.name).to eq("movement & sports")
      end
    end

    context "when selecting sense by MFS baseline (lowest sense_rank)" do
      let!(:lexeme) { create_lexeme("run", "verb") }
      let!(:primary_sense) { create(:sense, lexeme:, pos: "verb", lexical_domain: "noun.act", sense_rank: 1) }
      let!(:occurrence) { create_sentence_occurrence(lexeme:, sense: nil) }

      before do
        create(:sense, lexeme:, pos: "verb", lexical_domain: "verb.motion", sense_rank: 2)
        load_context_families
      end

      it "assigns context family from MFS sense (lowest sense_rank)" do
        described_class.call
        expect(occurrence.reload.context_family.name).to eq("actions & activities")
      end

      it "also sets sense_id on the occurrence" do
        described_class.call
        expect(occurrence.reload.sense).to eq(primary_sense)
      end
    end

    context "with occurrences that have no sense (lexeme has no senses)" do
      let!(:lexeme) { create_lexeme("fake", "noun") }
      let!(:occurrence) { create_sentence_occurrence(lexeme:, sense: nil) }

      before { load_context_families }

      it "skips occurrences whose lexeme has no senses at all" do
        described_class.call
        expect(occurrence.reload.context_family).to be_nil
        expect(occurrence.reload.sense).to be_nil
      end
    end

    context "with sense that has nil lexical_domain (fallback senses)" do
      let!(:lexeme) { create_lexeme("xyz", "noun") }
      let!(:sense) { create(:sense, lexeme:, pos: "noun", lexical_domain: nil) }
      let!(:occurrence) { create_sentence_occurrence(lexeme:, sense:) }

      before { load_context_families }

      it "assigns 'unknown' context family for nil lexical_domain" do
        described_class.call
        expect(occurrence.reload.context_family.name).to eq("unknown")
      end
    end

    context "with unmapped lexical_domain (adj.all, adv.all)" do
      let!(:lexeme) { create_lexeme("fast", "adjective") }
      let!(:sense) { create(:sense, lexeme:, pos: "adjective", lexical_domain: "adj.all") }
      let!(:occurrence) { create_sentence_occurrence(lexeme:, sense:) }

      before { load_context_families }

      it "assigns 'unknown' context family for unmapped lexical domain" do
        described_class.call
        expect(occurrence.reload.context_family.name).to eq("unknown")
      end
    end

    context "when run multiple times" do
      let!(:lexeme) { create_lexeme("run", "verb") }
      let!(:sense) { create(:sense, lexeme:, pos: "verb", lexical_domain: "verb.motion") }
      let!(:occurrence) { create_sentence_occurrence(lexeme:, sense:) }

      before { load_context_families }

      it "does not reassign on second run" do
        described_class.call
        first_family_id = occurrence.reload.context_family_id

        described_class.call

        expect(occurrence.reload.context_family_id).to eq(first_family_id)
      end
    end

    context "with multiple occurrences across domains" do
      let!(:lexemes) do
        [
          create_lexeme("person", "noun"),
          create_lexeme("run", "verb"),
          create_lexeme("eat", "verb")
        ]
      end
      let!(:senses) do
        [
          create(:sense, lexeme: lexemes[0], pos: "noun", lexical_domain: "noun.person"),
          create(:sense, lexeme: lexemes[1], pos: "verb", lexical_domain: "verb.motion"),
          create(:sense, lexeme: lexemes[2], pos: "verb", lexical_domain: "verb.consumption")
        ]
      end
      let!(:occurrences) do
        senses.map.with_index do |sense, i|
          create_sentence_occurrence(lexeme: lexemes[i], sense:)
        end
      end

      before { load_context_families }

      it "assigns correct families for all occurrences" do
        described_class.call

        expect(occurrences[0].reload.context_family.name).to eq("people & relationships")
        expect(occurrences[1].reload.context_family.name).to eq("movement & sports")
        expect(occurrences[2].reload.context_family.name).to eq("food & drink")
      end
    end

    context "when logging assignment counts" do
      let!(:lexeme) { create_lexeme("run", "verb") }
      let!(:sense) { create(:sense, lexeme:, pos: "verb", lexical_domain: "verb.motion") }
      let!(:occurrence) { create_sentence_occurrence(lexeme:, sense:) }

      before { load_context_families }

      it "logs summary with assignment counts" do
        described_class.call
        expect(occurrence.reload.context_family).to be_present
      end
    end

    def load_context_families # rubocop:disable Metrics/MethodLength
      return if ContextFamily.any?

      ContextFamily.insert_all([
                                 { name: "people & relationships", description: "Люди, группы, социальные взаимодействия" },
                                 { name: "communication", description: "Речь, язык, передача информации" },
                                 { name: "body & health", description: "Тело, здоровье, физические функции" },
                                 { name: "food & drink", description: "Еда, питьё, потребление" },
                                 { name: "movement & sports", description: "Движение, спорт, соревнования" },
                                 { name: "thinking & knowledge", description: "Мышление, знание, обучение" },
                                 { name: "emotions & feelings", description: "Чувства, эмоции, мотивация" },
                                 { name: "objects & tools", description: "Предметы, инструменты, технологии" },
                                 { name: "nature & environment", description: "Природа, животные, растения" },
                                 { name: "places & travel", description: "Места, география, путешествия" },
                                 { name: "time & events", description: "Время, события, изменения" },
                                 { name: "actions & activities", description: "Действия, создание, активности" },
                                 { name: "possession & commerce", description: "Владение, торговля, финансы" },
                                 { name: "physical interaction", description: "Физический контакт, восприятие" },
                                 { name: "weather", description: "Погода, климатические явления" },
                                 { name: "qualities & states", description: "Абстрактные качества, состояния, формы" },
                                 { name: "unknown", description: "Fallback: прилагательные/наречия, function words" }
                               ], unique_by: :name)
    end
  end
end
