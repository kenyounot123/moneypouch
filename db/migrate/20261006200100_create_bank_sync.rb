class CreateBankSync < ActiveRecord::Migration[8.1]
  def change
    create_table :simplefin_accesses do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :access_url
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    create_table :bank_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :simplefin_access, null: false, foreign_key: true, index: false
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :institution
      t.string :currency, null: false
      t.integer :balance_in_cents
      t.string :status, null: false, default: "pending"
      t.date :starts_on
      t.string :error_message
      t.timestamps
      t.index %i[ simplefin_access_id external_id ], unique: true
    end

    create_table :simplefin_syncs do |t|
      t.references :access, null: false, foreign_key: { to_table: :simplefin_accesses }, index: false
      t.datetime :finished_at
      t.string :failure
      t.timestamps
      t.index :access_id, unique: true, where: "finished_at IS NULL", name: "index_simplefin_syncs_one_running"
      t.index %i[ access_id finished_at ]
    end

    create_table :bank_transactions do |t|
      t.references :bank_account, null: false, foreign_key: true, index: false
      t.references :simplefin_sync, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true, index: { unique: true }
      t.string :external_id, null: false
      t.integer :amount_in_cents, null: false
      t.date :occurred_on, null: false
      t.string :description, null: false
      t.string :payee
      t.boolean :matched, null: false, default: false
      t.timestamps
      t.index %i[ bank_account_id external_id ], unique: true
    end
  end
end
