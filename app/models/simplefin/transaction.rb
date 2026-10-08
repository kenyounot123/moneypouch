Simplefin::Transaction = Data.define(:id, :amount_in_cents, :posted_at, :transacted_at, :description, :payee) do
  def occurred_on
    if transacted_at
      transacted_at.in_time_zone.to_date
    else
      posted_at.utc.to_date
    end
  end
end
