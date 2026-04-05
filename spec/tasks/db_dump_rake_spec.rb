require "rails_helper"
require "rake"

RSpec.describe "db:dump rake tasks" do # rubocop:disable RSpec/DescribeClass
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  before do
    Rake::Task["db:dump:create"].reenable
    Rake::Task["db:dump:restore"].reenable
  end

  describe "db:dump:create" do
    context "when pg_dump succeeds" do
      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow_any_instance_of(Object).to receive(:system).and_return(true) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Pathname).to receive(:size).and_return(10 * 1_048_576) # rubocop:disable RSpec/AnyInstance
      end

      it "prints the dump path and size" do
        expect { Rake::Task["db:dump:create"].invoke }
          .to output(/Dump created:.*development\.dump/).to_stdout
      end
    end

    context "when pg_dump fails" do
      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow_any_instance_of(Object).to receive(:system).and_return(false) # rubocop:disable RSpec/AnyInstance
      end

      it "aborts with an error message" do
        expect { Rake::Task["db:dump:create"].invoke }
          .to raise_error(SystemExit)
      end
    end
  end

  describe "db:dump:restore" do
    context "when dump file exists and pg_restore succeeds" do
      before do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Object).to receive(:system).and_return(true) # rubocop:disable RSpec/AnyInstance
      end

      it "prints restored message" do
        expect { Rake::Task["db:dump:restore"].invoke }
          .to output(/Restored from.*development\.dump/).to_stdout
      end
    end

    context "when dump file does not exist" do
      before do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(false) # rubocop:disable RSpec/AnyInstance
      end

      it "aborts with dump not found message" do
        expect { Rake::Task["db:dump:restore"].invoke }
          .to raise_error(SystemExit)
      end
    end

    context "when pg_restore fails" do
      before do
        allow_any_instance_of(Pathname).to receive(:exist?).and_return(true) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Object).to receive(:system).and_return(false) # rubocop:disable RSpec/AnyInstance
      end

      it "aborts" do
        expect { Rake::Task["db:dump:restore"].invoke }
          .to raise_error(SystemExit)
      end
    end
  end
end
