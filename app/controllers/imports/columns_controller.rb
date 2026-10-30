class Imports::ColumnsController < ApplicationController
  unavailable_in_demo

  include ImportScoped

  def edit
  end

  def update
    if @import.choose_columns(columns_params)
      redirect_to edit_import_categories_path(@import), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def columns_params
      params.expect(import: [ :positive_amounts, columns: [] ])
    end
end
