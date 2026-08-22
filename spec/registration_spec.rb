require "spec_helper"
require "yaml"

RSpec.describe "plugin registration" do
  it "configures every source cop and provides a matching spec" do
    root = File.expand_path("..", __dir__)
    configured = YAML.load_file(File.join(root, "config/default.yml")).keys.grep(%r{\AAntiSlop/})
    sources = Dir[File.join(root, "lib/anti_slop_ror/cops/no_*.rb")].map { |path| File.basename(path, ".rb") }
    expect(configured.length).to eq(sources.length)
    configured.each do |name|
      class_name = name.split("/").last.gsub(/([a-z])([A-Z])/, "\\1_\\2").downcase
      expect(sources).to include(class_name)
      expect(File).to exist(File.join(root, "spec/#{class_name}_spec.rb"))
      expect(RuboCop::Cop::Registry.global.find_by_cop_name(name)).not_to be_nil
    end
  end

  it "loads the lint roller plugin" do
    plugin = AntiSlopRor::Plugin.new
    expect(plugin).to be_a(LintRoller::Plugin)
    expect(plugin.about.homepage).to eq("https://github.com/sudhanshug16/anti-slop-ror")
    expect(plugin.rules(nil).value).to end_with("config/default.yml")
  end
end
