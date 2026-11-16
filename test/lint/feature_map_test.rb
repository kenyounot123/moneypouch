require "test_helper"

class FeatureMapTest < ActiveSupport::TestCase
  MAP = ".claude/skills/verify-moneypouch/**/*.md"

  CONSTANT = /\A(?:[A-Z]\w*::)+[A-Z]\w*\z/
  METHOD = /\A((?:[A-Z]\w*::)*[A-Z]\w*)([#.])(\w+[?!=]?)(?:\(.*\))?\z/
  ROUTE = %r{\A(?:(GET|POST|PATCH|PUT|DELETE) )?(/[\w/:.\-]*[a-z][\w/:.\-]*)(?:\?\S*)?\z}
  PATH = %r{\A[\w.\-]+(?:/[\w.\-*]+)+\.[a-z]+\z}
  DEVTOOLS_DOMAINS = %w[ DOM Input Network Page Runtime ].freeze
  RUNTIME_OUTPUT = %r{\A(?:log|tmp)/}
  PATH_ROOTS = [ "", "app/views/", "app/javascript/controllers/", "app/javascript/", "app/assets/images/" ].freeze

  test "every constant, method, file, and route the feature map names exists" do
    missing = references.reject { |_place, reference| exists?(reference) }

    assert missing.empty?, <<~MESSAGE
      The verify-moneypouch feature map names code that is gone. Update the map to what the code
      says now, in the same change that renamed or removed it.

      #{missing.map { |place, reference| "#{place}  `#{reference}`" }.join("\n")}
    MESSAGE
  end

  private
    def references
      Dir.glob(MAP, base: Rails.root).sort.flat_map do |path|
        Rails.root.join(path).each_line.with_index(1).flat_map do |line, number|
          line.scan(/`([^`\n]+)`/).flatten.map { |reference| [ "#{path}:#{number}", reference ] }
        end
      end
    end

    def exists?(reference)
      case reference
      when RUNTIME_OUTPUT, /\A[A-Z0-9_]+[.#]/, /\A(?:#{DEVTOOLS_DOMAINS.join("|")})\./
        true
      when CONSTANT
        constant(reference).present?
      when METHOD
        method_exists?($1, $2, $3)
      when ROUTE
        route_exists?($1, $2)
      when PATH
        path_exists?(reference)
      else
        true
      end
    end

    def constant(name)
      name.safe_constantize
    end

    def method_exists?(owner_name, kind, name)
      owner = constant(owner_name)

      if owner.nil?
        false
      elsif kind == "#"
        owner.define_attribute_methods if owner < ActiveRecord::Base
        owner.method_defined?(name) || owner.private_method_defined?(name)
      else
        owner.respond_to?(name, true)
      end
    end

    def route_exists?(verb, path)
      verbs = verb.nil? ? %w[ GET POST PATCH PUT DELETE ] : [ verb ]

      verbs.any? { |candidate| recognized?(candidate, path.gsub(/:\w+/, "1")) }
    end

    def recognized?(verb, path)
      Rails.application.routes.recognize_path(path, method: verb)
      true
    rescue ActionController::RoutingError
      false
    end

    def path_exists?(path)
      PATH_ROOTS.any? { |root| Dir.glob(Rails.root.join("#{root}#{path}")).any? }
    end
end
