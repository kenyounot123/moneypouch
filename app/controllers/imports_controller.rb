class ImportsController < ApplicationController
  def new
    @import = Current.user.imports.new
    @latest = Current.user.latest_import
  end

  def create
    @import = Current.user.start_import(params.expect(import: [ :file ])[:file])

    if @import.persisted?
      redirect_to edit_import_columns_path(@import), status: :see_other
    else
      @latest = Current.user.latest_import
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    import = Current.user.imports.find_by(id: params.expect(:id))

    if import
      import.undo
    end

    redirect_to new_import_path, status: :see_other
  end
end
