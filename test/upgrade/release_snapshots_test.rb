require "test_helper"
require "open3"

class ReleaseSnapshotsTest < ActiveSupport::TestCase
  SNAPSHOTS = Rails.root.join("test/fixtures/files/releases")

  test "the latest release has a snapshot" do
    version = JSON.parse(File.read(Rails.root.join(".release-please-manifest.json"))).fetch(".")

    assert SNAPSHOTS.join("v#{version}.sqlite3").exist?, "Run bin/rails releases:snapshot on the release pull request and commit the file"
  end

  SNAPSHOTS.glob("*.sqlite3").each do |snapshot|
    test "upgrading from #{snapshot.basename(".sqlite3")} keeps every transaction" do
      Dir.mktmpdir do |dir|
        database = File.join(dir, snapshot.basename)
        FileUtils.cp(snapshot, database)
        before = facts(database)

        upgrade(database, schema: File.join(dir, "schema.rb"))
        after = facts(database)

        assert_equal before[:transactions].keys, after[:transactions].keys
        before[:transactions].each do |id, row|
          assert_equal row.except("category"), after[:transactions][id].except("category"), "transaction #{id} changed"

          if row["category"]
            assert_equal row["category"], after[:transactions][id]["category"], "transaction #{id} lost its category"
          end
        end
        assert_equal before[:bank_transactions], after[:bank_transactions]
        assert_equal before[:counts], after[:counts]
        assert_equal [ [ "ok" ] ], query(database, "PRAGMA integrity_check")
        assert_empty query(database, "PRAGMA foreign_key_check")
        assert_equal File.read(Rails.root.join("db/schema.rb")), File.read(File.join(dir, "schema.rb")), "the upgraded schema differs from db/schema.rb"
      end
    end
  end

  private
    def upgrade(database, schema:)
      output, status = Open3.capture2e({ "DATABASE_URL" => "sqlite3:#{database}", "SCHEMA" => schema, "RAILS_ENV" => "test" }, "bin/rails", "db:prepare", "db:schema:dump", chdir: Rails.root)

      assert status.success?, output
    end

    def facts(database)
      transactions = query(database, <<~SQL).to_h { |id, *row| [ id, %w[ user name amount currency date note transfer discarded category ].zip(row).to_h ] }
        SELECT t.id, u.username, t.name, t.amount_in_cents, t.currency, t.occurred_on, t.note, t.transfer, t.discarded_at IS NOT NULL, c.name
        FROM transactions t JOIN users u ON u.id = t.user_id LEFT JOIN categories c ON c.id = t.category_id
        ORDER BY t.id
      SQL

      {
        transactions:,
        bank_transactions: query(database, "SELECT external_id, transaction_id, amount_in_cents, matched FROM bank_transactions ORDER BY id"),
        counts: %w[ users categories bank_accounts simplefin_syncs ].index_with { |table| query(database, "SELECT count(*) FROM #{table}").first.first }
      }
    end

    def query(database, sql)
      SQLite3::Database.new(database) { |db| return db.execute(sql) }
    end
end
