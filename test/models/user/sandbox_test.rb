require "test_helper"

class User::SandboxTest < ActiveSupport::TestCase
  include SimplefinTestHelper

  test "a sandbox is a fresh account full of sample transactions that expires in a day" do
    freeze_time

    sandbox = User.create_sandbox

    assert sandbox.sandbox?
    assert_equal 24.hours.from_now, sandbox.expires_at
    assert_match(/\Avisitor-/, sandbox.username)
    assert_operator sandbox.transactions.count, :>, User::Sandbox::SAMPLE_PURCHASES
    assert_not users(:one).sandbox?
  end

  test "deleting expired sandboxes leaves no row behind and keeps everyone else" do
    before = row_counts
    sandbox = User.create_sandbox
    fill_every_table_for(sandbox)
    unexpired = User.create_sandbox

    travel 25.hours
    unexpired.update!(expires_at: 1.hour.from_now)
    User.delete_expired_sandboxes

    assert_not User.exists?(sandbox.id)
    assert User.exists?(unexpired.id)
    unexpired.destroy!
    assert_equal before, row_counts
  end

  test "deleting expired sandboxes does nothing when there are none" do
    before = row_counts

    User.delete_expired_sandboxes

    assert_equal before, row_counts
  end

  test "a sandbox never owns the server, even when it is the oldest account" do
    sandbox = User.create_sandbox
    sandbox.update!(created_at: 1.year.ago)

    assert_equal users(:one), User.owner
    assert_not sandbox.owner?
  end

  test "registration is closed in the demo, even before anyone has an account" do
    Transaction.delete_all
    User.destroy_all

    with_demo do
      assert_not User.registration_open?
    end
    assert User.registration_open?
  end

  private
    def fill_every_table_for(user)
      user.transactions.first.discard
      user.sessions.create!
      user.remember(BankTransaction::Name.new(payee: "Blue Bottle", description: ""), Transaction::Categorization.new(category: user.categories.first))
      user.start_import(import_file("personal.csv"))

      access = connect_simplefin(user)
      activate(access)

      assert user.bank_transactions.any?, "the sandbox has bank rows to delete"
      assert user.rules.any?, "the sandbox has a rule to delete"
      assert user.imports.any?, "the sandbox has an import to delete"
    end

    def row_counts
      tables = ActiveRecord::Base.connection.tables - %w[ schema_migrations ar_internal_metadata ]
      tables.index_with { |table| ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{table}") }
    end
end
