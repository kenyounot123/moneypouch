require "test_helper"

class DemoHelperTest < ActionView::TestCase
  test "counts down the sandbox's deletion in whole hours, then minutes" do
    freeze_time
    sandbox = User.new(expires_at: 24.hours.from_now)

    assert_equal "Your sandbox is deleted in 24 hours.", sandbox_deletion_note(sandbox)

    travel 23.hours + 1.second
    assert_equal "Your sandbox is deleted in 1 hour.", sandbox_deletion_note(sandbox)

    travel 1.minute
    assert_equal "Your sandbox is deleted in 59 minutes.", sandbox_deletion_note(sandbox)

    travel 1.hour
    assert_equal "Your sandbox is deleted any minute now.", sandbox_deletion_note(sandbox)
  end
end
