namespace :dev do
  desc "Add N realistic purchases for the demo user across the last 12 months, plus a year of monthly bills and paychecks"
  task :transactions, [ :count ] => :environment do |_, args|
    count = Integer(args.fetch(:count, 100))
    Rails.application.load_seed
    user = User.find_by!(username: "demo")

    user.add_sample_transactions(count)

    puts "Added #{count} purchases and a year of bills and paychecks for demo, who now has #{user.transactions.count} transactions."
  end
end
