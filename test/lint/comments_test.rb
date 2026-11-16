require "test_helper"
require "ripper"

class CommentsTest < ActiveSupport::TestCase
  OUTSIDE_THINGS = %w[ Browsers Chrome Excel Keyboards Rails Ruby SimpleFIN SQLite Turbo ].freeze
  DIRECTIVES = [ "locals:", "herb:disable", "frozen_string_literal:" ].freeze

  GENERATED = {
    "app/assets/stylesheets/application.css" => [ "* This is a manifest file that'll be compiled into application.css." ],
    "app/controllers/application_controller.rb" => [
      "Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.",
      "Changes to the importmap will invalidate the etag for HTML responses"
    ],
    "app/javascript/application.js" => [ "Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails" ],
    "app/javascript/controllers/application.js" => [ "Configure Stimulus development experience" ],
    "app/javascript/controllers/index.js" => [ "Import and register all your controllers from the importmap via controllers/**/*_controller" ],
    "app/views/layouts/application.html.erb" => [ "Includes all stylesheet files in app/assets/stylesheets" ],
    "test/test_helper.rb" => [
      "Run tests in parallel with specified workers",
      "Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.",
      "Add more helper methods to be used by all tests here..."
    ]
  }.freeze

  test "a comment names a constraint from outside the app or is not there" do
    offenses = comments.reject { |path, _line, text| allowed?(path, text) }

    assert offenses.empty?, <<~MESSAGE
      Say it in code instead: name the method, variable, or constant for what the comment explains.
      A comment may only state a constraint from outside the app, and starts with what imposes it:
      #{OUTSIDE_THINGS.map { |thing| "#{thing}:" }.join(" ")}. A new outside thing goes in
      CommentsTest::OUTSIDE_THINGS, which a human approves in review.

      #{offenses.map { |path, line, text| "#{path}:#{line}  #{text}" }.join("\n")}
    MESSAGE
  end

  private
    def allowed?(path, text)
      if text.start_with?(*DIRECTIVES)
        true
      elsif GENERATED.fetch(path, []).include?(text)
        true
      else
        OUTSIDE_THINGS.any? { |thing| text.start_with?("#{thing}: ") }
      end
    end

    def comments
      project_files.flat_map do |path|
        comment_lines(path).sort_by(&:first).uniq(&:first).map { |line, text| [ path, line, text ] }
      end
    end

    def project_files
      code = Dir.glob("{app,lib,test}/**/*.{rb,rake,erb,js,mjs,css}", base: Rails.root)
      scripts = Dir.glob("script/*", base: Rails.root)

      (code + scripts).reject { |path| path.start_with?("app/assets/builds/") }
    end

    def comment_lines(path)
      source = Rails.root.join(path).read

      case File.extname(path)
      when ".rb", ".rake"
        ruby_comments(source)
      when ".erb"
        matches(source, /<%#\s*(.*?)\s*%>/m)
      when ".js", ".mjs"
        matches(source, %r{(?:^|\s)//\s?(.*)$}) + matches(source, %r{/\*+\s*(.*?)$})
      when ".css"
        matches(source, %r{/\*+\s*(.*?)$}).map { |line, text| css_block_text(source, line, text) }
      else
        shell_comments(source)
      end
    end

    def ruby_comments(source)
      Ripper.lex(source).filter_map do |(line, _column), type, token|
        if type == :on_comment && !token.start_with?("#!")
          [ line, token.delete_prefix("#").strip ]
        end
      end
    end

    def shell_comments(source)
      source.each_line.with_index(1).filter_map do |text, line|
        if text.match?(/\A\s*#(?!!)/)
          [ line, text.strip.delete_prefix("#").strip ]
        end
      end
    end

    def matches(source, pattern)
      source.to_enum(:scan, pattern).map do
        match = Regexp.last_match
        [ source[0...match.begin(0)].count("\n") + 1, match[1].strip ]
      end
    end

    def css_block_text(source, line, text)
      if text.empty?
        [ line, source.lines[line].strip ]
      else
        [ line, text ]
      end
    end
end
