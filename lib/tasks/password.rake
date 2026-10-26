require "io/console"

namespace :password do
  desc "Reset a user's password and sign them out everywhere"
  task reset: :environment do
    owner = User.owner
    abort "No accounts yet. Create one in the browser first." unless owner

    ask = ->(prompt, secret: false) do
      $stdout.print prompt
      $stdout.flush
      line = secret && $stdin.tty? ? $stdin.noecho(&:gets).tap { $stdout.puts } : $stdin.gets
      line.to_s.chomp
    end

    username = ask.("Username [#{owner.username}]: ").presence || owner.username
    user = User.find_by(username:) || abort("No account named #{username}.")
    password = ask.("New password: ", secret: true)
    confirmation = ask.("Confirm: ", secret: true)

    if user.reset_password(password, confirmation)
      puts "Password changed for #{user.username}. Every device is signed out."
    else
      abort user.errors.full_messages.to_sentence
    end
  end
end
