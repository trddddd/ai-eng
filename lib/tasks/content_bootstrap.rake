# rubocop:disable Metrics/BlockLength
namespace :content_bootstrap do
  desc "Import Oxford 5000 lexemes"
  task import_oxford_lexemes: :environment do
    ContentBootstrap::ImportOxfordLexemes.call
  end

  desc "Import NGSL Core lexemes"
  task import_ngsl_core_lexemes: :environment do
    ContentBootstrap::ImportNgslCoreLexemes.call
  end

  desc "Import NGSL Spoken lexemes"
  task import_ngsl_spoken_lexemes: :environment do
    ContentBootstrap::ImportNgslSpokenLexemes.call
  end

  desc "Import Poliglot Russian glosses"
  task import_poliglot_glosses: :environment do
    ContentBootstrap::ImportPoliglotGlosses.call
  end

  desc "Import sentences from Quizword (deprecated: use import_tatoeba)"
  task import_quizword: :environment do
    Sentences::ImportQuizword.call
  end

  desc "Import sentences from Tatoeba CSV files in db/data/tatoeba/ (FT-029, replaces import_quizword)"
  task import_tatoeba: :environment do
    Sentences::ImportTatoeba.call
  end

  desc "Import senses from WordNet 3.1 (FT-029)"
  task import_senses: :environment do
    ContentBootstrap::ImportSenses.call
  end

  desc "Assign fallback senses for lexemes without WordNet match (FT-029)"
  task assign_fallback_senses: :environment do
    ContentBootstrap::AssignFallbackSenses.call
  end

  desc "Seed context families from ADR-002 taxonomy (FT-029)"
  task seed_context_families: :environment do
    load Rails.root.join("db/seeds/context_families.rb")
  end

  desc "Assign context families to occurrences based on sense lexical domains (FT-029)"
  task assign_context_families: :environment do
    ContentBootstrap::AssignContextFamilies.call
  end

  desc "Backfill sense and context_family for existing sentence occurrences (FT-029)"
  task backfill_sense_data: %i[
    seed_context_families
    import_senses
    assign_fallback_senses
    assign_context_families
  ]

  desc "Run full content bootstrap (Oxford → NGSL Core → NGSL Spoken → Poliglot → Tatoeba → Sense data)"
  task import_all: %i[
    import_oxford_lexemes
    import_ngsl_core_lexemes
    import_ngsl_spoken_lexemes
    import_poliglot_glosses
    import_tatoeba
    backfill_sense_data
  ]
end
# rubocop:enable Metrics/BlockLength
