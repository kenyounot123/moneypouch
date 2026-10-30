require "test_helper"

class SandboxesControllerTest < ActionDispatch::IntegrationTest
  test "trying the demo signs a visitor in to a fresh sandbox full of transactions" do
    with_demo do
      assert_difference -> { User.sandboxes.count }, 1 do
        post sandbox_path
      end

      assert_redirected_to root_path
      follow_redirect!
      assert_response :success

      sandbox = User.sandboxes.last
      assert_equal 1, sandbox.sessions.count
      assert_operator sandbox.transactions.count, :>, User::Sandbox::SAMPLE_PURCHASES
    end
  end

  test "there is no sandbox outside the demo" do
    assert_no_difference -> { User.count } do
      post sandbox_path
    end

    assert_response :not_found
  end

  test "one visitor can make five sandboxes in ten minutes" do
    with_demo do
      with_rate_limit_counting do
        5.times { post sandbox_path }
        assert_difference -> { User.sandboxes.count }, 0 do
          post sandbox_path
        end

        assert_redirected_to new_session_path
        follow_redirect!
        assert_select "#alert", text: /Try again in a few minutes/

        travel 11.minutes
        assert_difference -> { User.sandboxes.count }, 1 do
          post sandbox_path
        end
      end
    end
  end

  private
    def with_rate_limit_counting
      memory = ActiveSupport::Cache::MemoryStore.new
      Rails.cache.define_singleton_method(:increment) { |*args, **options| memory.increment(*args, **options) }
      yield
    ensure
      Rails.cache.singleton_class.remove_method(:increment)
    end
end
