# rubocop:disable Metrics/BlockLength
namespace :db do
  namespace :dump do
    desc "Create a pg_dump of the development database"
    task create: :environment do
      dump_path = Rails.root.join("db/dump/development.dump")
      FileUtils.mkdir_p(dump_path.dirname)

      success = system(
        "docker compose exec -T postgres " \
        "pg_dump -U lingvize -Fc lingvize_development",
        out: dump_path.to_s
      )

      abort "pg_dump failed" unless success

      size_mb = (dump_path.size / 1_048_576.0).round(1)
      puts "Dump created: #{dump_path} (#{size_mb} MB)"
    end

    desc "Restore the development database from a pg_dump"
    task restore: :environment do
      dump_path = Rails.root.join("db/dump/development.dump")
      abort "Dump not found: #{dump_path}" unless dump_path.exist?

      success = system(
        "docker compose exec -T postgres " \
        "pg_restore -U lingvize -d lingvize_development --clean --if-exists",
        in: dump_path.to_s
      )

      abort "pg_restore failed" unless success

      puts "Restored from #{dump_path}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
