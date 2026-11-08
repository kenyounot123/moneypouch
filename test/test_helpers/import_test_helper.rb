module ImportTestHelper
  def import_file(name)
    Rack::Test::UploadedFile.new(file_fixture("imports/#{name}"))
  end

  def upload(name, content)
    Tempfile.create([ "upload", File.extname(name) ]) do |file|
      file.binmode
      file.write(content)
      file.close
      Rack::Test::UploadedFile.new(file.path, original_filename: name)
    end
  end

  # Four of personal.csv's rows, in file order, each already here a different way: typed in, from an earlier import, from the bank, and deleted.
  def have_personal_rows(user)
    typed = user.transactions.create!(name: "Whole Foods", amount_in_cents: -123_456, occurred_on: "2024-10-02")
    earlier = user.imports.create!(file: upload("earlier.csv", "Date,Item,Category,Amount\n2024-10-04,Trader Joe's,Groceries,42.10\n2024-10-07,Groceries,Groceries,18.00\n"))
    earlier.complete
    deleted = earlier.transactions.find_by!(name: "Groceries").tap(&:discard)
    banked = user.transactions.create!(name: "Rent", amount_in_cents: -200_000, occurred_on: "2024-10-06")
    access = connect_simplefin(user)
    access.bank_accounts.find_by!(external_id: "Demo Checking").bank_transactions.create!(simplefin_sync: access.syncs.create!, transaction_id: banked.id, external_id: "rent",
      amount_in_cents: -200_000, occurred_on: banked.occurred_on, description: "Rent", name_key: "rent")

    [ typed, earlier.transactions.find_by!(name: "Trader Joe's"), banked, deleted ]
  end

  def xlsx(entries)
    Zip::OutputStream.write_buffer do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end.string
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include ImportTestHelper
end
