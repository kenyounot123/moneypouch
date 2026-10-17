namespace :dev do
  desc "Add N realistic transactions for the demo user across the last 12 months"
  task :transactions, [ :count ] => :environment do |_, args|
    count = Integer(args.fetch(:count, 100))
    Rails.application.load_seed
    user = User.find_by!(username: "demo")

    merchants = {
      "Food" => [ [ "Blue Bottle", 4..7 ], [ "Sweetgreen", 12..18 ], [ "Chipotle", 10..16 ], [ "Joe's Pizza", 4..12 ],
                  [ "Starbucks", 3..8 ], [ "Shake Shack", 11..20 ], [ "Pho Saigon", 13..19 ], [ "Taco Bell", 6..12 ] ],
      "Groceries" => [ [ "Trader Joe's", 25..90 ], [ "Whole Foods", 30..140 ], [ "Safeway", 20..110 ], [ "Costco", 80..260 ] ],
      "Transport" => [ [ "Uber", 9..38 ], [ "Lyft", 8..34 ], [ "Shell", 35..70 ], [ "Clipper", 2..10 ] ],
      "Shopping" => [ [ "Amazon", 8..120 ], [ "Target", 15..95 ], [ "Uniqlo", 25..80 ], [ "Ikea", 20..240 ] ],
      "Bills" => [ [ "Comcast", 70..90 ], [ "PG&E", 60..180 ], [ "Verizon", 55..85 ], [ "Rent", 2100..2100 ] ],
      "Fun" => [ [ "Netflix", 15..23 ], [ "Spotify", 11..11 ], [ "AMC", 14..40 ], [ "Steam", 5..60 ] ],
      "Health" => [ [ "CVS", 6..45 ], [ "Walgreens", 5..40 ], [ "Equinox", 240..240 ] ]
    }.flat_map { |category, list| list.map { |name, dollars| [ name, dollars, category ] } }
    places = %w[ Mission SoMa Marina Castro Richmond Sunset Noe Haight Dogpatch Presidio Bernal Embarcadero Nob Hill
                 Potrero Excelsior Bayview Tenderloin Chinatown Fillmore Hayes Downtown Midtown Uptown Oakland Berkeley
                 Emeryville Alameda Fremont Hayward Sausalito Burlingame Menlo Cupertino Sunnyvale Campbell Saratoga
                 Tiburon Napa Sonoma Petaluma Novato Larkspur Pacifica Millbrae Belmont Woodside Atherton Milpitas
                 Livermore Pleasanton Dublin Danville Lafayette Orinda Walnut Concord Martinez Benicia Vallejo
                 Albany Piedmont Montclair Rockridge Temescal Fruitvale Jingletown ]
    variants = merchants.product(places).map { |(name, dollars, category), place| [ "#{name} #{place}", dollars, category ] }

    categories = (merchants.map(&:last) << "Income").uniq.index_with do |name|
      user.categories.named(name).first_or_create!(name: name)
    end

    today = Date.current
    rows = Array.new(count) do |index|
      occurred_on = today - rand(365)
      if rand < 0.04
        name, cents, category = "Paycheck", rand(180_000..320_000), "Income"
      else
        name, dollars, category = index % 4 == 0 ? variants[(index / 4) % variants.size] : merchants.sample
        cents = -rand((dollars.begin * 100)..(dollars.end * 100))
      end
      added_at = occurred_on.in_time_zone.change(hour: rand(7..22), min: rand(60))
      amount = format("%s%.2f", cents.positive? ? "+" : "", cents.abs / 100.0)

      { user_id: user.id, category_id: categories.fetch(category).id, name: name, amount_in_cents: cents, currency: "USD",
        occurred_on: occurred_on, shorthand: "#{name} #{amount} ##{category} #{occurred_on.iso8601}",
        created_at: added_at, updated_at: added_at }
    end
    rows.each_slice(1000) { |batch| Transaction.insert_all!(batch) }

    puts "Added #{count} transactions for demo, who now has #{user.transactions.count}."
  end
end
