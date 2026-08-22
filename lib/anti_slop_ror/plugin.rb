require "lint_roller"
require "lint_roller/plugin"
require "lint_roller/rules"
require_relative "version"
require_relative "cops/base"
Dir[File.join(__dir__, "cops/*.rb")].sort.each { |file| require file }

module AntiSlopRor
  class Plugin < LintRoller::Plugin
    def about
      LintRoller::About.new(name: "anti-slop-ror", version: VERSION, homepage: "https://github.com/sudhanshug16/anti-slop-ror")
    end

    def supported?(context)
      context.engine == :rubocop
    end

    def rules(_context)
      LintRoller::Rules.new(type: :path, config_format: :rubocop, value: File.expand_path("../../config/default.yml", __dir__))
    end
  end
end
