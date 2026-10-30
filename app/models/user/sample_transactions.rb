module User::SampleTransactions
  MERCHANTS = {
    "Food" => [ [ "Blue Bottle", 4..7 ], [ "Sweetgreen", 12..18 ], [ "Chipotle", 10..16 ], [ "Joe's Pizza", 4..12 ],
                [ "Starbucks", 3..8 ], [ "Shake Shack", 11..20 ], [ "Pho Saigon", 13..19 ], [ "Taco Bell", 6..12 ] ],
    "Groceries" => [ [ "Trader Joe's", 25..90 ], [ "Whole Foods", 30..140 ], [ "Safeway", 20..110 ], [ "Costco", 80..260 ] ],
    "Transport" => [ [ "Uber", 9..38 ], [ "Lyft", 8..34 ], [ "Shell", 35..70 ], [ "Clipper", 2..10 ] ],
    "Shopping" => [ [ "Amazon", 8..120 ], [ "Target", 15..95 ], [ "Uniqlo", 25..80 ], [ "Ikea", 20..240 ] ],
    "Bills" => [ [ "Comcast", 70..90 ], [ "PG&E", 60..180 ], [ "Verizon", 55..85 ], [ "Rent", 2100..2100 ] ],
    "Fun" => [ [ "Netflix", 15..23 ], [ "Spotify", 11..11 ], [ "AMC", 14..40 ], [ "Steam", 5..60 ] ],
    "Health" => [ [ "CVS", 6..45 ], [ "Walgreens", 5..40 ], [ "Equinox", 240..240 ] ]
  }.flat_map { |category, list| list.map { |name, dollars| [ name, dollars, category ] } }.freeze

  PLACES = %w[ Mission SoMa Marina Castro Richmond Sunset Noe Haight Dogpatch Presidio Bernal Embarcadero Nob Hill
               Potrero Excelsior Bayview Tenderloin Chinatown Fillmore Hayes Downtown Midtown Uptown Oakland Berkeley
               Emeryville Alameda Fremont Hayward Sausalito Burlingame Menlo Cupertino Sunnyvale Campbell Saratoga
               Tiburon Napa Sonoma Petaluma Novato Larkspur Pacifica Millbrae Belmont Woodside Atherton Milpitas
               Livermore Pleasanton Dublin Danville Lafayette Orinda Walnut Concord Martinez Benicia Vallejo
               Albany Piedmont Montclair Rockridge Temescal Fruitvale Jingletown ].freeze

  # Every fourth row names a branch ("Uber Mission"), so search and Tab completion have many names to match.
  BRANCHES = MERCHANTS.product(PLACES).map { |(name, dollars, category), place| [ "#{name} #{place}", dollars, category ] }.freeze

  # Spreads count made-up transactions across the last 12 months, with an occasional paycheck.
  def add_sample_transactions(count)
    categories = sample_categories
    today = Date.current

    rows = Array.new(count) do |index|
      sample_transaction(index, today - rand(365), categories)
    end

    rows.each_slice(1000) { |batch| Transaction.insert_all!(batch) }
  end

  private
    def sample_categories
      (MERCHANTS.map(&:last) << Category::INCOME).uniq.index_with do |name|
        categories.named(name).first_or_create!(name:)
      end
    end

    def sample_transaction(index, occurred_on, categories)
      if rand < 0.04
        name, cents, category = "Paycheck", rand(180_000..320_000), Category::INCOME
      else
        if index % 4 == 0
          name, dollars, category = BRANCHES[(index / 4) % BRANCHES.size]
        else
          name, dollars, category = MERCHANTS.sample
        end
        cents = -rand((dollars.begin * 100)..(dollars.end * 100))
      end

      added_at = occurred_on.in_time_zone.change(hour: rand(7..22), min: rand(60))
      amount = format("%s%.2f", cents.positive? ? "+" : "", cents.abs / 100.0)

      { user_id: id, category_id: categories.fetch(category).id, name:, amount_in_cents: cents, currency: "USD",
        occurred_on:, shorthand: "#{name} #{amount} ##{category} #{occurred_on.iso8601}",
        created_at: added_at, updated_at: added_at }
    end
end
