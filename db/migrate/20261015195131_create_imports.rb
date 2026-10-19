class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.references :user, null: false, index: false, foreign_key: true
      t.string :filename, null: false
      t.text :sheet
      t.text :columns, null: false
      t.text :category_names, null: false, default: "{}"
      t.datetime :completed_at
      t.timestamps

      t.index :user_id, unique: true, where: "completed_at IS NULL", name: "index_imports_one_draft"
      t.index [ :user_id, :completed_at ]
      t.check_constraint "(completed_at IS NULL) = (sheet IS NOT NULL)", name: "draft_has_a_sheet"
    end

    add_reference :transactions, :import, foreign_key: { on_delete: :nullify }
    add_reference :categories, :import, foreign_key: { on_delete: :nullify }
  end
end
