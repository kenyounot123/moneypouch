class CreateBankAccountFormerIds < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_account_former_ids do |t|
      t.references :bank_account, null: false, foreign_key: true
      t.references :simplefin_access, null: false, foreign_key: true, index: false
      t.string :external_id, null: false
      t.timestamps
      t.index %i[ simplefin_access_id external_id ], unique: true
    end

    up_only { execute "UPDATE bank_accounts SET reported_at = NULL WHERE missing_since IS NOT NULL AND reported_at = updated_at" }
  end
end
