module SimplefinAccessScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_simplefin_access
  end

  private
    def set_simplefin_access
      @access = Current.user.simplefin_access

      if @access.nil?
        raise ActiveRecord::RecordNotFound
      end
    end
end
