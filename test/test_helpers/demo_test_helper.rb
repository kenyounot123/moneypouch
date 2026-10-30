module DemoTestHelper
  def with_demo
    Rails.configuration.x.demo = true
    yield
  ensure
    Rails.configuration.x.demo = false
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include DemoTestHelper
end
