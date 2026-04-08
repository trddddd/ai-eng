require "rails_helper"
# rubocop:disable RSpec/LetSetup, RSpec/MultipleMemoizedHelpers, RSpec/AnyInstance
RSpec.describe Sentences::ImportQuizword do
  let(:fixture_html) { Rails.root.join("spec/fixtures/files/quizword_page.html").read }
  let!(:en_lang) { create(:language, code: "en", name: "English") }

  let(:ok_response) do
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      allow(response).to receive(:body).and_return(fixture_html)
    end
  end

  def html_response(html)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      allow(response).to receive(:body).and_return(html)
    end
  end

  def empty_page_response
    html_response(<<~HTML)
      <!DOCTYPE html>
      <html>
      <body>
      <div id="main">
        <div>
          <div>header placeholder</div>
          <div>footer placeholder</div>
        </div>
      </div>
      </body>
      </html>
    HTML
  end

  def call_ignoring_system_exit
    described_class.call
  rescue SystemExit
    nil
  end

  around do |example|
    original_env = {
      "START_PAGE" => ENV.fetch("START_PAGE", nil),
      "END_PAGE" => ENV.fetch("END_PAGE", nil),
      "CONCURRENCY" => ENV.fetch("CONCURRENCY", nil)
    }

    ENV["START_PAGE"] = "1"
    ENV["END_PAGE"] = "1"
    ENV["CONCURRENCY"] = "1"

    create(:language, code: "ru", name: "Russian")

    example.run
  ensure
    original_env.each { |key, value| value.nil? ? ENV.delete(key) : (ENV[key] = value) }
  end

  context "with fixture page and matching lexemes" do
    let!(:running_lexeme) { create(:lexeme, language: en_lang, headword: "running") }
    let!(:read_lexeme) { create(:lexeme, language: en_lang, headword: "read") }

    before { allow(Net::HTTP).to receive(:get_response).and_return(ok_response) }

    it "imports 2 sentences" do
      expect { described_class.call }.to change(Sentence, :count).by(2)
    end

    it "imports 2 sentence translations" do
      expect { described_class.call }.to change(SentenceTranslation, :count).by(2)
    end

    it "imports 2 sentence occurrences" do
      expect { described_class.call }.to change(SentenceOccurrence, :count).by(2)
    end

    it "skips the blank row" do
      expect { described_class.call }.to output(/Skipped rows: 1/).to_stdout
    end

    it "prints progress while importing" do
      expect { described_class.call }.to output(%r{Progress: 1/1 pages}).to_stdout
    end
  end

  context "when a sentence has no matching lexeme" do
    let!(:running_lexeme) { create(:lexeme, language: en_lang, headword: "running") }

    before { allow(Net::HTTP).to receive(:get_response).and_return(ok_response) }

    it "skips sentences without a matching lexeme" do
      expect { described_class.call }.to change(Sentence, :count).by(1)
    end

    it "increments skipped rows for no-match sentences" do
      expect { described_class.call }.to output(/Skipped rows: 2/).to_stdout
    end
  end

  context "when multiple lexemes match the same sentence" do
    let!(:run_lexeme) { create(:lexeme, language: en_lang, headword: "run") }
    let!(:running_lexeme) { create(:lexeme, language: en_lang, headword: "running") }
    let!(:read_lexeme) { create(:lexeme, language: en_lang, headword: "read") }

    before { allow(Net::HTTP).to receive(:get_response).and_return(ok_response) }

    it "selects the longest matching headword" do
      described_class.call

      occurrence = SentenceOccurrence.joins(:sentence)
                                     .find_by(sentences: { text: "She is running fast." })

      expect(occurrence.lexeme_id).to eq(running_lexeme.id)
    end
  end

  context "when tie-break rules apply" do
    let(:tie_html) do
      <<~HTML
        <!DOCTYPE html>
        <html><body>
        <div id="main"><div>
          <div>header</div>
          <div>
            <div>1</div>
            <div>I like cats and dogs.</div>
            <div>X</div>
            <div></div>
            <div>Мне нравятся кошки и собаки.</div>
          </div>
          <div>footer</div>
        </div></div>
        </body></html>
      HTML
    end

    before { allow(Net::HTTP).to receive(:get_response).and_return(html_response(tie_html)) }

    context "when headwords have equal length, earliest index wins" do
      let!(:cats_lexeme) { create(:lexeme, language: en_lang, headword: "cats") }
      let!(:dogs_lexeme) { create(:lexeme, language: en_lang, headword: "dogs") }

      it "selects the lexeme with the earliest position in the sentence" do
        described_class.call

        occurrence = SentenceOccurrence.joins(:sentence)
                                       .find_by(sentences: { text: "I like cats and dogs." })

        expect(occurrence.lexeme_id).to eq(cats_lexeme.id)
      end
    end

    context "when headwords have equal length and equal index, lexicographic order wins" do
      let(:same_pos_html) do
        <<~HTML
          <!DOCTYPE html>
          <html><body>
          <div id="main"><div>
            <div>header</div>
            <div>
              <div>1</div>
              <div>The bat and bay are here.</div>
              <div>X</div>
              <div></div>
              <div>Бита и залив здесь.</div>
            </div>
            <div>footer</div>
          </div></div>
          </body></html>
        HTML
      end

      let!(:bay_lexeme) { create(:lexeme, language: en_lang, headword: "bay") }
      let!(:bat_lexeme) { create(:lexeme, language: en_lang, headword: "bat") }

      before { allow(Net::HTTP).to receive(:get_response).and_return(html_response(same_pos_html)) }

      it "selects the lexicographically smallest headword" do
        described_class.call

        occurrence = SentenceOccurrence.joins(:sentence)
                                       .find_by(sentences: { text: "The bat and bay are here." })

        expect(occurrence.lexeme_id).to eq(bat_lexeme.id)
      end
    end

    context "when headwords and positions are identical, smaller lexeme id wins" do
      let(:same_headword_html) do
        <<~HTML
          <!DOCTYPE html>
          <html><body>
          <div id="main"><div>
            <div>header</div>
            <div>
              <div>1</div>
              <div>Read this now.</div>
              <div>X</div>
              <div></div>
              <div>Прочитай это сейчас.</div>
            </div>
            <div>footer</div>
          </div></div>
          </body></html>
        HTML
      end

      let!(:ru_lang) { create(:language, code: "uk", name: "Ukrainian") }
      let!(:first_lexeme) { create(:lexeme, language: en_lang, headword: "read") }
      let!(:second_lexeme) { create(:lexeme, language: ru_lang, headword: "read") }

      before { allow(Net::HTTP).to receive(:get_response).and_return(html_response(same_headword_html)) }

      it "selects the lexeme with the smaller id" do
        described_class.call

        occurrence = SentenceOccurrence.joins(:sentence)
                                       .find_by(sentences: { text: "Read this now." })

        expect(occurrence.lexeme_id).to eq([first_lexeme.id, second_lexeme.id].min)
      end
    end
  end

  context "when the same fixture is imported twice" do
    let!(:running_lexeme) { create(:lexeme, language: en_lang, headword: "running") }
    let!(:read_lexeme) { create(:lexeme, language: en_lang, headword: "read") }

    before { allow(Net::HTTP).to receive(:get_response).and_return(ok_response) }

    it "does not change sentence count on second run" do
      described_class.call
      expect { described_class.call }.not_to change(Sentence, :count)
    end

    it "does not change translation count on second run" do
      described_class.call
      expect { described_class.call }.not_to change(SentenceTranslation, :count)
    end

    it "does not change occurrence count on second run" do
      described_class.call
      expect { described_class.call }.not_to change(SentenceOccurrence, :count)
    end
  end

  context "when END_PAGE is not set" do
    let!(:running_lexeme) { create(:lexeme, language: en_lang, headword: "running") }
    let!(:read_lexeme) { create(:lexeme, language: en_lang, headword: "read") }

    around do |example|
      original_end = ENV.fetch("END_PAGE", nil)
      ENV.delete("END_PAGE")
      example.run
    ensure
      original_end.nil? ? ENV.delete("END_PAGE") : (ENV["END_PAGE"] = original_end)
    end

    before do
      allow(Net::HTTP).to receive(:get_response) do |uri|
        page = URI(uri.to_s).query[/page=(\d+)/, 1].to_i

        case page
        when 1, 2
          ok_response
        else
          empty_page_response
        end
      end
    end

    it "discovers the last non-empty page and imports through it" do
      expect { described_class.call }.to change(Sentence, :count).by(2)
      expect(Net::HTTP).to have_received(:get_response).with(instance_of(URI::HTTPS)).at_least(3).times
    end
  end

  context "when HTTP returns 429" do
    let!(:run_lexeme) { create(:lexeme, language: en_lang, headword: "run") }
    let(:rate_limit_response) do
      instance_double(Net::HTTPResponse).tap do |response|
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      end
    end

    before { allow(Net::HTTP).to receive(:get_response).and_return(rate_limit_response) }

    it "adds the URL to failed_urls in the summary" do
      expect { described_class.call }.to output(/Failed URLs: 1/).to_stdout
    end

    it "exits with code 0" do
      expect { described_class.call }.not_to raise_error
    end
  end

  context "when HTTP raises Net::ReadTimeout on every attempt" do
    let!(:run_lexeme) { create(:lexeme, language: en_lang, headword: "run") }

    before do
      allow_any_instance_of(described_class).to receive(:sleep)
      allow(Net::HTTP).to receive(:get_response).and_raise(Net::ReadTimeout)
    end

    it "retries and adds the URL to failed_urls" do
      expect { described_class.call }.to output(/Failed URLs: 1/).to_stdout
    end

    it "calls get_response 4 times (1 initial + 3 retries)" do
      described_class.call
      expect(Net::HTTP).to have_received(:get_response).exactly(4).times
    end
  end

  context "when lexemes table is empty" do
    it "aborts with a message about missing lexemes" do
      expect { described_class.call }.to raise_error(SystemExit)
    end

    it "does not create any records" do
      expect { call_ignoring_system_exit }.not_to change(Sentence, :count)
    end
  end

  context "when a lexeme appears as a substring inside another word" do
    let!(:cat_lexeme) { create(:lexeme, language: en_lang, headword: "cat") }

    let(:substring_html) do
      <<~HTML
        <!DOCTYPE html>
        <html><body>
        <div id="main"><div>
          <div>header</div>
          <div>
            <div>1</div>
            <div>The category is broad.</div>
            <div>X</div>
            <div></div>
            <div>Категория широка.</div>
          </div>
          <div>footer</div>
        </div></div>
        </body></html>
      HTML
    end

    before { allow(Net::HTTP).to receive(:get_response).and_return(html_response(substring_html)) }

    it "does not create a sentence occurrence" do
      expect { described_class.call }.not_to change(SentenceOccurrence, :count)
    end

    it "increments skipped rows" do
      expect { described_class.call }.to output(/Skipped rows: 1/).to_stdout
    end
  end

  context "when lexeme 'ago' appears inside 'agony'" do
    let!(:ago_lexeme) { create(:lexeme, language: en_lang, headword: "ago") }

    let(:agony_html) do
      <<~HTML
        <!DOCTYPE html>
        <html><body>
        <div id="main"><div>
          <div>header</div>
          <div>
            <div>1</div>
            <div>What agony it was.</div>
            <div>X</div>
            <div></div>
            <div>Какая это была агония.</div>
          </div>
          <div>footer</div>
        </div></div>
        </body></html>
      HTML
    end

    before { allow(Net::HTTP).to receive(:get_response).and_return(html_response(agony_html)) }

    it "does not create a sentence occurrence" do
      expect { described_class.call }.not_to change(SentenceOccurrence, :count)
    end

    it "increments skipped rows" do
      expect { described_class.call }.to output(/Skipped rows: 1/).to_stdout
    end
  end

  context "when the same lexeme appears as a whole word" do
    let!(:ago_lexeme) { create(:lexeme, language: en_lang, headword: "ago") }

    let(:ago_html) do
      <<~HTML
        <!DOCTYPE html>
        <html><body>
        <div id="main"><div>
          <div>header</div>
          <div>
            <div>1</div>
            <div>I saw it three years ago.</div>
            <div>X</div>
            <div></div>
            <div>Я видел это три года назад.</div>
          </div>
          <div>footer</div>
        </div></div>
        </body></html>
      HTML
    end

    before { allow(Net::HTTP).to receive(:get_response).and_return(html_response(ago_html)) }

    it "creates a sentence occurrence with the correct lexeme" do
      described_class.call

      occurrence = SentenceOccurrence.joins(:sentence)
                                     .find_by(sentences: { text: "I saw it three years ago." })

      expect(occurrence.lexeme_id).to eq(ago_lexeme.id)
    end

    it "extracts the form preserving original case" do
      described_class.call

      occurrence = SentenceOccurrence.joins(:sentence)
                                     .find_by(sentences: { text: "I saw it three years ago." })

      expect(occurrence.form).to eq("ago")
    end
  end

  context "when headword contains regex special characters" do
    let!(:dont_lexeme) { create(:lexeme, language: en_lang, headword: "don't") }

    let(:dont_html) do
      <<~HTML
        <!DOCTYPE html>
        <html><body>
        <div id="main"><div>
          <div>header</div>
          <div>
            <div>1</div>
            <div>I don't know.</div>
            <div>X</div>
            <div></div>
            <div>Я не знаю.</div>
          </div>
          <div>footer</div>
        </div></div>
        </body></html>
      HTML
    end

    before { allow(Net::HTTP).to receive(:get_response).and_return(html_response(dont_html)) }

    it "matches the lexeme correctly" do
      described_class.call

      occurrence = SentenceOccurrence.joins(:sentence)
                                     .find_by(sentences: { text: "I don't know." })

      expect(occurrence.lexeme_id).to eq(dont_lexeme.id)
    end

    it "preserves original case in form" do
      described_class.call

      occurrence = SentenceOccurrence.joins(:sentence)
                                     .find_by(sentences: { text: "I don't know." })

      expect(occurrence.form).to eq("don't")
    end
  end

  context "when START_PAGE > END_PAGE" do
    around do |example|
      original_start = ENV.fetch("START_PAGE", nil)
      original_end = ENV.fetch("END_PAGE", nil)

      ENV["START_PAGE"] = "3"
      ENV["END_PAGE"] = "1"

      example.run
    ensure
      original_start.nil? ? ENV.delete("START_PAGE") : (ENV["START_PAGE"] = original_start)
      original_end.nil? ? ENV.delete("END_PAGE") : (ENV["END_PAGE"] = original_end)
    end

    let!(:run_lexeme) { create(:lexeme, language: en_lang, headword: "run") }

    it "aborts with an invalid page range message" do
      expect { described_class.call }.to raise_error(SystemExit)
    end

    it "does not create any records" do
      expect { call_ignoring_system_exit }.not_to change(Sentence, :count)
    end
  end
end
# rubocop:enable RSpec/LetSetup, RSpec/MultipleMemoizedHelpers, RSpec/AnyInstance
