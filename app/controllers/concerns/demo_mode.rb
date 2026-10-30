module DemoMode
  extend ActiveSupport::Concern

  included do
    helper_method :demo?
  end

  class_methods do
    def unavailable_in_demo(**options)
      before_action :not_found_in_demo, **options
    end

    def only_in_demo(**options)
      before_action :not_found_outside_demo, **options
    end
  end

  private
    def demo?
      Rails.configuration.x.demo
    end

    def not_found_in_demo
      if demo?
        head :not_found
      end
    end

    def not_found_outside_demo
      unless demo?
        head :not_found
      end
    end
end
