require "test_helper"
require "open3"

class BackupTest < ActiveSupport::TestCase
  test "a restore after a crash brings back what the app had committed when the backup ran" do
    Dir.mktmpdir do |storage|
      database = File.join(storage, "production.sqlite3")
      live = SQLite3::Database.new(database)
      live.execute("PRAGMA journal_mode = WAL")
      live.execute("CREATE TABLE transactions (name TEXT)")
      live.execute("INSERT INTO transactions VALUES ('Chipotle'), ('Uber')")

      run_hook "pre-backup", storage
      live.execute("INSERT INTO transactions VALUES ('After the backup')")
      crash(live, database)

      run_hook "post-restore", storage

      SQLite3::Database.new(database) do |restored|
        assert_equal [ [ "ok" ] ], restored.execute("PRAGMA integrity_check")
        assert_equal [ [ "Chipotle" ], [ "Uber" ] ], restored.execute("SELECT name FROM transactions")
      end
    end
  end

  private
    def crash(live, database)
      wal = File.binread("#{database}-wal")
      live.close
      File.binwrite("#{database}-wal", wal)
    end

    def run_hook(name, storage)
      output, status = Open3.capture2e({ "STORAGE_DIR" => storage, "RAILS_ENV" => "production" }, Rails.root.join("hooks", name).to_s)

      assert status.success?, output
    end
end
