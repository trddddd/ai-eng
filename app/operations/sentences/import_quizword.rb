require "net/http"

module Sentences
  # rubocop:disable Metrics/ClassLength
  class ImportQuizword
    BASE_URL = "https://quizword.net/ru-en/sentences/?page=".freeze
    BATCH_SIZE = 1000
    RETRYABLE = [Net::OpenTimeout, Net::ReadTimeout, SocketError, EOFError, Errno::ECONNRESET].freeze

    def self.call = new.call

    def call
      validate_env!
      preload_languages!
      check_lexemes!
      lexemes = Lexeme.pluck(:id, :headword)
      pages = build_pages
      queue = build_queue(pages)
      results = run_pool(queue, lexemes)
      print_summary(**results)
    end

    private

    def start_page  = Integer(ENV.fetch("START_PAGE", 1))
    def end_page    = @end_page ||= explicit_end_page || discover_end_page
    def concurrency = Integer(ENV.fetch("CONCURRENCY", 10))
    def explicit_end_page = ENV.key?("END_PAGE") ? Integer(ENV.fetch("END_PAGE")) : nil

    def validate_env!
      s = start_page
      e = end_page
      c = concurrency
      # rubocop:disable Rails/Exit
      abort "Invalid page range or concurrency" unless s >= 1 && e >= 1 && c >= 1 && s <= e
    rescue ArgumentError
      abort "Invalid page range or concurrency"
      # rubocop:enable Rails/Exit
    end

    def preload_languages!
      @en = find_or_create_language("en", "English")
      @ru = find_or_create_language("ru", "Russian")
    end

    def find_or_create_language(code, name)
      Language.find_or_create_by!(code: code, name: name)
    rescue ActiveRecord::RecordNotUnique
      Language.find_by!(code: code)
    end

    def check_lexemes!
      # rubocop:disable Rails/Exit
      abort "No lexemes in DB. Run content_bootstrap:import_all first" if Lexeme.none?
      # rubocop:enable Rails/Exit
    end

    def build_pages
      (start_page..end_page).to_a
    end

    def build_queue(pages)
      q = Queue.new
      pages.each { |page| q << page }
      concurrency.times { q << :stop }
      q
    end

    # rubocop:disable Metrics/AbcSize, Metrics/BlockLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def run_pool(queue, lexemes)
      total_pages = end_page - start_page + 1
      imported = 0
      failed_urls = []
      skipped = 0
      processed_pages = 0
      mutex = Mutex.new

      threads = concurrency.times.map do
        Thread.new do
          loop do
            page = queue.pop
            break if page == :stop

            url = "#{BASE_URL}#{page}"
            response = fetch_page(url)

            if response == :failed
              mutex.synchronize do
                failed_urls << url
                processed_pages += 1
                print_progress(
                  processed_pages: processed_pages,
                  total_pages: total_pages,
                  imported: imported,
                  failed_count: failed_urls.size,
                  skipped: skipped,
                  page: page
                )
              end
              next
            end

            rows, blank_skipped = parse_sentences(response.body)
            valid_rows = []
            page_skipped = blank_skipped

            rows.each do |row|
              match = find_lexeme(row[:text_eng], lexemes)
              if match.nil?
                page_skipped += 1
                next
              end

              lexeme_id, hw = match
              form = row[:text_eng][row[:text_eng].downcase.index(word_boundaries_regex(hw)), hw.length]
              valid_rows << row.merge(lexeme_id: lexeme_id, form: form)
            end

            if valid_rows.any?
              count = insert_batch(valid_rows)
              mutex.synchronize do
                imported += count
                skipped += page_skipped
                processed_pages += 1
                print_progress(
                  processed_pages: processed_pages,
                  total_pages: total_pages,
                  imported: imported,
                  failed_count: failed_urls.size,
                  skipped: skipped,
                  page: page
                )
              end
            else
              mutex.synchronize do
                skipped += page_skipped
                processed_pages += 1
                print_progress(
                  processed_pages: processed_pages,
                  total_pages: total_pages,
                  imported: imported,
                  failed_count: failed_urls.size,
                  skipped: skipped,
                  page: page
                )
              end
            end
          end
        end
      end

      threads.each(&:join)
      { imported: imported, failed_urls: failed_urls, skipped: skipped }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/BlockLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def fetch_page(url)
      retries = 0
      begin
        response = Net::HTTP.get_response(URI(url))
        return response if response.is_a?(Net::HTTPSuccess)

        :failed
      rescue *RETRYABLE
        retries += 1
        if retries <= 3
          sleep(2**(retries - 1))
          retry
        end
        :failed
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def parse_sentences(html)
      doc = Nokogiri::HTML(html)
      container = doc.at_xpath('//*[@id="main"]/div')
      nodes = container&.element_children&.[](1..-2) || []
      skipped = 0

      rows = nodes.filter_map do |node|
        text_eng = node.search("div")[1]&.text&.strip
        text_rus = extract_translation(node)
        audio_html = node.search("div")[3]&.to_html.to_s
        audio_id = audio_html[/\b(\d{1,10})\b/, 1]&.to_i
        if text_eng.blank? || text_rus.blank?
          skipped += 1
          next
        end

        { text_eng: text_eng, text_rus: text_rus, audio_id: audio_id }
      end

      [rows, skipped]
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def discover_end_page
      page = start_page
      last_non_empty_page = nil

      loop do
        response = fetch_page(page_url(page))
        break if response == :failed || page_empty?(response.body)

        last_non_empty_page = page
        page *= 2
      end

      return start_page if last_non_empty_page.nil?

      low = last_non_empty_page
      high = page - 1

      while low < high
        mid = (low + high + 1) / 2
        response = fetch_page(page_url(mid))

        if response != :failed && !page_empty?(response.body)
          low = mid
        else
          high = mid - 1
        end
      end

      low
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def word_boundaries_regex(headword)
      Regexp.new("\\b#{Regexp.escape(headword)}\\b", Regexp::IGNORECASE)
    end

    def find_lexeme(text_eng, lexemes)
      downcased = text_eng.downcase
      candidates = lexemes.select { |_id, hw| word_boundaries_regex(hw).match?(downcased) }
      return nil if candidates.empty?

      candidates.min_by do |id, hw|
        idx = downcased.index(word_boundaries_regex(hw))
        [-hw.length, idx, hw.downcase, id.to_s]
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/BlockLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def insert_batch(valid_rows)
      now = Time.current

      ApplicationRecord.transaction do
        existing_texts = Sentence
                         .where(language_id: @en.id, text: valid_rows.map { |row| row[:text_eng] })
                         .pluck(:text)
                         .to_set

        sentence_rows = valid_rows.map do |row|
          {
            language_id: @en.id,
            text: row[:text_eng],
            audio_id: row[:audio_id],
            source: "quizword",
            created_at: now,
            updated_at: now
          }
        end

        Sentence.insert_all(
          sentence_rows,
          unique_by: :index_sentences_on_language_id_and_text
        )

        text_to_id = Sentence
                     .where(language_id: @en.id, text: valid_rows.map { |r| r[:text_eng] })
                     .pluck(:text, :id)
                     .to_h

        translation_rows = valid_rows.filter_map do |row|
          sid = text_to_id[row[:text_eng]]
          next unless sid

          {
            sentence_id: sid,
            target_language_id: @ru.id,
            text: row[:text_rus],
            created_at: now,
            updated_at: now
          }
        end

        if translation_rows.any?
          SentenceTranslation.insert_all(
            translation_rows,
            unique_by: %i[sentence_id target_language_id]
          )
        end

        occurrence_rows = valid_rows.filter_map do |row|
          sid = text_to_id[row[:text_eng]]
          next unless sid

          {
            sentence_id: sid,
            lexeme_id: row[:lexeme_id],
            form: row[:form],
            created_at: now,
            updated_at: now
          }
        end

        if occurrence_rows.any?
          SentenceOccurrence.insert_all(occurrence_rows,
                                        unique_by: :index_sentence_occurrences_on_sentence_id_and_lexeme_id)
        end

        valid_rows.count { |row| existing_texts.exclude?(row[:text_eng]) }
      end
    rescue ActiveRecord::ActiveRecordError => e
      # rubocop:disable Rails/Exit
      abort "DB error: #{e.message}"
      # rubocop:enable Rails/Exit
    end
    # rubocop:enable Metrics/AbcSize, Metrics/BlockLength, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def extract_translation(node)
      node.search("div")[4]&.text.to_s.strip.split("  ").first.to_s.strip
    end

    def page_empty?(html)
      rows, = parse_sentences(html)
      rows.empty?
    end

    def page_url(page)
      "#{BASE_URL}#{page}"
    end

    # rubocop:disable Rails/Output
    def print_progress(**progress)
      puts [
        "Progress: #{progress[:processed_pages]}/#{progress[:total_pages]} pages.",
        "Current page: #{progress[:page]}.",
        "Imported: #{progress[:imported]}.",
        "Failed URLs: #{progress[:failed_count]}.",
        "Skipped rows: #{progress[:skipped]}"
      ].join(" ")
    end
    # rubocop:enable Rails/Output

    def print_summary(imported:, failed_urls:, skipped:)
      # rubocop:disable Rails/Output
      puts "Quizword done. Imported: #{imported}. Failed URLs: #{failed_urls.size}. Skipped rows: #{skipped}"
      # rubocop:enable Rails/Output
    end
  end
  # rubocop:enable Metrics/ClassLength
end
