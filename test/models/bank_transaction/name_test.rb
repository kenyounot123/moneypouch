require "test_helper"

class BankTransaction::NameTest < ActiveSupport::TestCase
  test "uses the payee the bank cleaned up" do
    assert_equal [ "MTA OMNY", "mta omny" ], read("MTA OMNY", "MTA*NYCT PAYGO")
  end

  test "falls back to the description without a payee" do
    assert_equal [ "Grocery store", "grocery store" ], read(nil, "Grocery store")
  end

  test "drops the Zelle prefix and reference code" do
    assert_equal [ "Avery Stone", "avery stone" ], read("Zelle Transfer to Avery Stone Jpm99abc12de", "Zelle payment to Avery Stone JPM99abc12de")
    assert_equal [ "Morgan Lee", "morgan lee" ], read("Zelle Transfer from Morgan Lee", "Zelle payment from MORGAN LEE 30452922617")
  end

  test "reads the person from the description when the payee only says Zelle" do
    assert_equal [ "Riley Park", "riley park" ], read("Zelle Transfer", "Zelle payment from Riley Park COFGSBQZBEW5")
  end

  test "drops trailing store numbers and ids" do
    assert_equal [ "PANDA EXPRESS", "panda express" ], read(nil, "PANDA EXPRESS 2769")
    assert_equal [ "Spotify", "spotify" ], read(nil, "Spotify P455942347")
  end

  test "keeps a name that is only a number-bearing word" do
    assert_equal [ "7-Eleven", "eleven" ], read("7-Eleven", "7-ELEVEN 3341")
  end

  test "keys card payments to the same card the same way" do
    assert_equal read(nil, "Payment to Chase card ending in 5653 08/24").last, read(nil, "Payment to Chase card ending in 5653 09/24").last
  end

  private
    def read(payee, description)
      name = BankTransaction::Name.new(payee:, description:)
      [ name.to_s, name.key ]
    end
end
