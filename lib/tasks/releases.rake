namespace :releases do
  desc "Save a database filled by this release's code, for test/upgrade to migrate forward"
  task snapshot: :environment do
    version = JSON.parse(File.read(Rails.root.join(".release-please-manifest.json"))).fetch(".")
    path = Rails.root.join("test/fixtures/files/releases/v#{version}.sqlite3")
    FileUtils.mkdir_p(path.dirname)
    FileUtils.rm_f([ path, "#{path}-wal", "#{path}-shm" ])

    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: path.to_s)
    ActiveRecord::Schema.verbose = false
    load Rails.root.join("db/schema.rb")

    random = Random.new(2026)
    today = Date.new(2026, 10, 1)

    ActiveRecord::Base.transaction do
      [ [ "alex", "America/New_York" ], [ "sam", "UTC" ] ].each do |username, time_zone|
        user = User.create!(username:, password: "snapshot-password", time_zone:)
        categories = %w[ Food Groceries Transport Bills Fun ].index_with { |name| user.categories.create!(name:) }
        merchants = [ [ "Chipotle", "Food" ], [ "Trader Joe's", "Groceries" ], [ "Uber", "Transport" ], [ "Comcast", "Bills" ], [ "AMC", "Fun" ] ]

        typed = Array.new(150) do |index|
          name, category = merchants[index % merchants.size]
          occurred_on = today - random.rand(365)
          user.transactions.create!(
            name:,
            amount_in_cents: -random.rand(300..9_000),
            occurred_on:,
            category: index % 11 == 0 ? nil : categories.fetch(category),
            shorthand: "#{name} #{random.rand(3..90)}",
            note: index % 9 == 0 ? "Split with Jo" : nil,
            created_at: occurred_on.in_time_zone(time_zone).change(hour: 20) + random.rand(0..3).days
          )
        end
        typed.select.with_index { |_, index| index % 17 == 0 }.each(&:discard)

        12.times do |month|
          user.transactions.create!(name: "Paycheck", amount_in_cents: 310_000, occurred_on: today << month)
          user.transactions.create!(name: "Card payment", amount_in_cents: -120_000, occurred_on: (today << month) + 3, transfer: true)
          user.transactions.create!(name: "Reimbursed dinner", amount_in_cents: -6_400, occurred_on: (today << month) + 5, excluded: true)
        end

        history = "Date,Description,Amount,Category\n" + Array.new(40) { |index| "#{(today - 400 - index).iso8601},Corner Deli,-#{random.rand(4..30)}.50,#{index.even? ? "Food" : "Lunch"}\n" }.join
        [ history, "Date,Description,Amount\n#{(today - 3).iso8601},Bookshop,-24.00\n" ].each_with_index do |text, index|
          Tempfile.create([ "history", ".csv" ]) do |file|
            file.write(text)
            file.close
            import = user.imports.create!(file: ActionDispatch::Http::UploadedFile.new(tempfile: File.open(file.path), filename: "history-#{index}.csv"))
            import.complete if index.zero?
          end
        end

        next unless username == "alex"

        access = user.create_simplefin_access!(status: "active")
        accounts = [ [ "ACT-checking", "Everyday Checking" ], [ "ACT-card", "Rewards Card" ], [ "ACT-savings", "Savings" ] ].map do |external_id, name|
          access.update_account(Simplefin::Account.new(id: external_id, name:, institution: "Demo Bank", currency: "USD", balance_in_cents: 250_000, error_message: nil, transactions: []))
        end
        accounts[0].start_syncing(from: today - 90)
        accounts[1].start_syncing(from: today - 90)
        accounts[2].skip

        sync = access.syncs.create!
        kept = typed.reject(&:discarded_at).select { |transaction| transaction.occurred_on >= today - 90 }
        accounts.first(2).each_with_index do |bank_account, account_index|
          posted = kept.select.with_index { |_, index| index % 2 == account_index }.first(10).map do |transaction|
            Simplefin::Transaction.new(id: "TRN-match-#{transaction.id}", amount_in_cents: transaction.amount_in_cents, posted_at: transaction.occurred_on.to_time + 1.day, transacted_at: nil, description: "#{transaction.name.upcase} 4471", payee: transaction.name)
          end
          posted += Array.new(25) do |index|
            payee = [ "Blue Bottle", "Shell", "Netflix", "Costco", "Zelle payment to Jo" ][index % 5]
            Simplefin::Transaction.new(id: "TRN-new-#{account_index}-#{index}", amount_in_cents: -random.rand(400..20_000), posted_at: (today - random.rand(90)).to_time, transacted_at: nil, description: "#{payee.upcase} #{random.rand(1000..9999)}", payee:)
          end
          bank_account.add_transactions(posted, sync:)
        end
        sync.update!(finished_at: Time.current, reviewed_at: Time.current)

        added = user.transactions.added_by_bank.order(:id)
        { "Blue Bottle" => [ categories.fetch("Food"), categories.fetch("Fun") ], "Shell" => [ categories.fetch("Transport") ] * 2 }.each do |name, picks|
          accounts.first(2).zip(picks).each do |bank_account, category|
            transaction = added.find { |candidate| candidate.name == name && candidate.bank_transaction.bank_account == bank_account }
            transaction.categorize(Transaction::Categorization.new(category:))
            transaction.make_rule
          end
        end
        added.find { |candidate| candidate.name == "Jo" }.categorize(Transaction::Categorization.transfer)
      end
    end

    ActiveRecord::Base.connection.execute("PRAGMA journal_mode = DELETE")
    ActiveRecord::Base.connection.execute("VACUUM")
    ActiveRecord::Base.connection_pool.disconnect!
    puts "Saved #{path.relative_path_from(Rails.root)}"
  end
end
