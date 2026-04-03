module ContentBootstrap
  class BaseOperation
    DEFAULT_DATA_DIR = Rails.root.join("db/data").freeze

    def self.call(...)
      new(...).call
    end

    def initialize(data_dir: DEFAULT_DATA_DIR)
      @data_dir = data_dir
    end

    private

    def data_path(filename)
      path = @data_dir.join(filename)
      raise "File not found: #{path}" unless path.exist?

      path
    end

    def now
      @now ||= Time.current
    end

    def normalize_headword(word)
      word.strip
    end
  end
end
