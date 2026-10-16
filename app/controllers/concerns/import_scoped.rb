module ImportScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_import
  end

  private
    def set_import
      @import = Current.user.imports.find(params.expect(:import_id))

      if @import.completed?
        redirect_to new_import_path, status: :see_other
      end
    end
end
