class AddReviewedAtToSimplefinSyncs < ActiveRecord::Migration[8.1]
  def change
    add_column :simplefin_syncs, :reviewed_at, :datetime
  end
end
