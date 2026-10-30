namespace :dev do
  desc "Add N realistic transactions for the demo user across the last 12 months"
  task :transactions, [ :count ] => :environment do |_, args|
    count = Integer(args.fetch(:count, 100))
    Rails.application.load_seed
    user = User.find_by!(username: "demo")

    user.add_sample_transactions(count)

    puts "Added #{count} transactions for demo, who now has #{user.transactions.count}."
  end
end
