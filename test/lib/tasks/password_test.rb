require "test_helper"
require "rake"

class PasswordTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("password:reset")
    Rake::Task["password:reset"].reenable
  end

  test "resets the named user's password and signs them out" do
    user = users(:two)
    user.sessions.create!

    output = run_reset("two\nnew-secret\nnew-secret\n")

    assert user.reload.authenticate("new-secret")
    assert_empty user.sessions
    assert_match(/Password changed for two/, output)
  end

  test "a blank username picks the owner" do
    run_reset("\nnew-secret\nnew-secret\n")

    assert users(:one).reload.authenticate("new-secret")
  end

  test "an unknown username changes nothing" do
    error = assert_raises(SystemExit) { run_reset("nobody\nnew-secret\nnew-secret\n") }

    assert_equal 1, error.status
    assert users(:one).reload.authenticate("password")
  end

  test "a mismatched confirmation changes nothing" do
    user = users(:two)
    user.sessions.create!

    assert_raises(SystemExit) { run_reset("two\nnew-secret\nother\n") }

    assert user.reload.authenticate("password")
    assert_equal 1, user.sessions.count
  end

  private
    def run_reset(input)
      original_stdin = $stdin
      $stdin = StringIO.new(input)
      capture_io { Rake::Task["password:reset"].invoke }.first
    ensure
      $stdin = original_stdin
    end
end
