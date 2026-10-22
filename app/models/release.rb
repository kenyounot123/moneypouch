class Release < Data.define(:version, :date, :sections)
  Section = Data.define(:title, :items)

  SECTION_TITLES = { "Features" => "New", "Bug Fixes" => "Fixed", "Performance Improvements" => "Faster" }

  HEADING = /\A## \[?(?<version>\d+(?:\.\d+)*)\]?(?:\(\S+\))?(?: \((?<date>\d{4}-\d{2}-\d{2})\))?\s*\z/
  SCOPE = /\A\*\*[^*]+:\*\* /
  LINKS = /(?:\s*\(\[[^\]]+\]\([^)]+\)\))+\z/

  class << self
    def current_version
      @current_version ||= Rails.root.join("version.txt").read.strip
    end

    def all
      @all ||= parse(Rails.root.join("CHANGELOG.md").read)
    end

    def newer_than(version, among: all)
      among.select do |release|
        release.newer_than?(version) && !release.newer_than?(current_version)
      end
    end

    def parse(text)
      text.split(/^(?=## )/).filter_map do |chunk|
        heading, *sections = chunk.split(/^(?=### )/)

        match = HEADING.match(heading.lines.first.to_s)

        if match
          new(version: match[:version], date: match[:date]&.to_date, sections: sections.map { |section| parse_section(section) })
        end
      end
    end

    private
      def parse_section(text)
        heading, *lines = text.lines(chomp: true)
        name = heading.delete_prefix("### ").strip
        items = lines.grep(/\A\* /).map { |line| clean(line.delete_prefix("* ")) }

        Section.new(title: SECTION_TITLES.fetch(name, name), items:)
      end

      def clean(item)
        item.sub(SCOPE, "").sub(LINKS, "").sub(/\A./) { |first| first.upcase }
      end
  end

  def newer_than?(other)
    Gem::Version.new(version) > Gem::Version.new(other)
  end
end
