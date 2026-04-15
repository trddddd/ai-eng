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

  desc "Download Tatoeba per-language TSV files to db/data/tatoeba/ (requires curl + bzip2)"
  task download_tatoeba: :environment do
    dir = Rails.root.join("db/data/tatoeba")
    FileUtils.mkdir_p(dir)

    files = {
      "eng_sentences.tsv" => "https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2",
      "rus_sentences.tsv" => "https://downloads.tatoeba.org/exports/per_language/rus/rus_sentences.tsv.bz2"
    }
    files.each do |name, url|
      dest = dir.join(name)
      if dest.exist?
        puts "#{name} already exists, skipping"
        next
      end
      tmp = dir.join("#{name}.bz2")
      puts "Downloading #{url}..."
      system("curl -L --progress-bar #{url} -o #{tmp}") || abort("curl failed for #{url}")
      puts "Extracting #{name}..."
      system("bzip2 -d #{tmp}") || abort("bzip2 failed for #{tmp}")
      puts "#{name} ready (#{(File.size(dest) / 1_048_576.0).round(1)} MB)"
    end

    links = dir.join("links.csv")
    if links.exist?
      puts "links.csv already exists, skipping"
    else
      tmp_bz2 = dir.join("links.tar.bz2")
      puts "Downloading links.tar.bz2 (large file, ~200 MB compressed)..."
      url = "https://downloads.tatoeba.org/exports/links.tar.bz2"
      system("curl -L --progress-bar #{url} -o #{tmp_bz2}") || abort("curl failed for links.tar.bz2")
      puts "Extracting links.csv..."
      system("tar -xjf #{tmp_bz2} -C #{dir}") || abort("tar failed")
      FileUtils.rm_f(tmp_bz2)
      puts "links.csv ready (#{(File.size(links) / 1_048_576.0).round(1)} MB)"
    end

    puts "\nAll Tatoeba files ready in #{dir}"
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
