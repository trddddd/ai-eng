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

  desc "Run full content bootstrap (Oxford → NGSL Core → NGSL Spoken → Poliglot)"
  task import_all: %i[
    import_oxford_lexemes
    import_ngsl_core_lexemes
    import_ngsl_spoken_lexemes
    import_poliglot_glosses
  ]
end
