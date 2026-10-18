require "test_helper"

class ReleaseTest < ActiveSupport::TestCase
  CHANGELOG = <<~MARKDOWN
    # Changelog

    ## [0.2.0](https://github.com/example/app/compare/v0.1.0...v0.2.0) (2026-10-16)


    ### Features

    * **settings:** download every transaction as a CSV file ([#95](https://github.com/example/app/issues/95)) ([d63baf7](https://github.com/example/app/commit/d63baf73))
    * hand-drawn icons and a clearer filter bar ([#100](https://github.com/example/app/issues/100)) ([b4eeeb8](https://github.com/example/app/commit/b4eeeb8e))


    ### Bug Fixes

    * **import:** bring in transfers, and skip rows already in the account ([#96](https://github.com/example/app/issues/96)) ([8fc9de0](https://github.com/example/app/commit/8fc9de05))


    ### Performance Improvements

    * **transactions:** render a busy month in pages of whole days ([#101](https://github.com/example/app/issues/101)) ([113e30b](https://github.com/example/app/commit/113e30b3))

    ## 0.1.0 (2026-10-12)


    ### Features

    * **brand:** use the app's pouch for the favicon ([#66](https://github.com/example/app/issues/66)) ([0fe2fcf](https://github.com/example/app/commit/0fe2fcf9))


    ### Documentation

    * **readme:** explain how to install ([#70](https://github.com/example/app/issues/70)) ([a38481a](https://github.com/example/app/commit/a38481a3))
  MARKDOWN

  test "parses each release with its version and date, newest first" do
    releases = Release.parse(CHANGELOG)

    assert_equal [ "0.2.0", "0.1.0" ], releases.map(&:version)
    assert_equal [ Date.new(2026, 10, 16), Date.new(2026, 10, 12) ], releases.map(&:date)
  end

  test "names sections in the app's words and keeps other names as written" do
    releases = Release.parse(CHANGELOG)

    assert_equal [ "New", "Fixed", "Faster" ], releases.first.sections.map(&:title)
    assert_equal [ "New", "Documentation" ], releases.last.sections.map(&:title)
  end

  test "drops the scope and the links from a scoped item and capitalizes it" do
    section = Release.parse(CHANGELOG).first.sections.first

    assert_equal "Download every transaction as a CSV file", section.items.first
  end

  test "cleans an item that has no scope" do
    section = Release.parse(CHANGELOG).first.sections.first

    assert_equal "Hand-drawn icons and a clearer filter bar", section.items.second
  end

  test "keeps punctuation inside an item" do
    section = Release.parse(CHANGELOG).first.sections.second

    assert_equal [ "Bring in transfers, and skip rows already in the account" ], section.items
  end

  test "reads the first release heading, which has no link" do
    release = Release.parse(CHANGELOG).last

    assert_equal "0.1.0", release.version
    assert_equal "Use the app's pouch for the favicon", release.sections.first.items.first
  end

  test "a release without a date has none" do
    release = Release.parse("## 0.3.0\n\n### Features\n\n* **a:** b ([#1](https://x.test/1))\n").first

    assert_nil release.date
    assert_equal [ "B" ], release.sections.first.items
  end

  test "reads the real changelog" do
    release = Release.all.find { |release| release.version == "0.6.0" }

    assert_equal Date.new(2026, 10, 16), release.date
    assert_includes release.sections.first.items, "Download every transaction as a CSV file"
  end

  test "the current version comes from version.txt" do
    assert_equal Rails.root.join("version.txt").read.strip, Release.current_version
  end

  test "newer_than lists releases after the given version, newest first" do
    releases = Release.parse(CHANGELOG)

    assert_equal [ "0.2.0" ], Release.newer_than("0.1.0", among: releases).map(&:version)
    assert_equal [], Release.newer_than("0.2.0", among: releases).map(&:version)
  end

  test "newer_than leaves out a release after the running version" do
    releases = Release.parse("## 99.0.0 (2099-01-01)\n\n## 0.1.0 (2026-10-12)\n")

    assert_equal [ "0.1.0" ], Release.newer_than("0.0.1", among: releases).map(&:version)
  end

  test "newer_than compares versions as numbers" do
    releases = Release.parse("## 0.7.0 (2026-10-18)\n")

    assert_equal [], Release.newer_than("0.10.0", among: releases)
  end
end
