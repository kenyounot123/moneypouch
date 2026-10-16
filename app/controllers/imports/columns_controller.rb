class Imports::ColumnsController < ApplicationController
  include ImportScoped

  def edit
  end

  def update
    if @import.update(columns: Import::Columns.from(params, sheet: @import.sheet))
      redirect_to edit_import_categories_path(@import), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
