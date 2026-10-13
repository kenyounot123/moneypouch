require "test_helper"

class TypographyTest < ActiveSupport::TestCase
  OFF_SYSTEM = /\bfont-pixel\b|\btracking-|\b(?:text|leading)-\[\d/

  test "views style text with the type scale and roles only" do
    offenders = Rails.root.glob("app/{views,helpers,javascript}/**/*.{erb,rb,js}").flat_map do |path|
      path.each_line.with_index(1).filter_map do |line, number|
        "#{path.relative_path_from(Rails.root)}:#{number} #{line[OFF_SYSTEM]}" if line.match?(OFF_SYSTEM)
      end
    end

    assert_empty offenders, <<~MESSAGE
      Use a role from app/assets/tailwind/application.css (text-display, text-title, text-heading, text-button, text-button-sm)
      or a size from the scale (text-xs, text-sm, text-base, text-md, text-lg) instead of a pixel font, tracking, or bracketed size.
    MESSAGE
  end
end
