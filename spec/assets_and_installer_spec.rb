require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "vendored assets" do
  let(:root) { File.expand_path("..", __dir__) }

  it "has no asset drift" do
    expect(system({"BUNDLE_GEMFILE" => File.join(root, "Gemfile")}, "ruby", "scripts/sync_skill_assets.rb", "--check", chdir: root)).to be(true)
  end

  it "installs an isolated snapshot without changing project configuration" do
    Dir.mktmpdir do |target|
      standard = File.join(target, ".standard.yml")
      File.write(standard, "ignore: []\n")
      output = `ruby #{File.join(root, "scripts/install.rb").inspect} #{target.inspect}`
      expect($?.success?).to be(true)
      expect(File).to exist(File.join(target, "tools/anti_slop_ror/lib/anti_slop_ror/plugin.rb"))
      expect(File.read(standard)).to eq("ignore: []\n")
      expect(output).to include("plugin_class_name: AntiSlopRor::Plugin")
    end
  end

  it "loads the vendored plugin through StandardRB" do
    Dir.mktmpdir do |target|
      install_snapshot(target)
      File.write(File.join(target, ".standard.yml"), standard_plugin_config)
      File.write(File.join(target, "clean.rb"), "User.where(name: params[:name])\n")
      File.write(File.join(target, "violation.rb"), "User.where(\"name = '\#{params[:name]}'\")\n")
      environment = {"BUNDLE_GEMFILE" => File.join(root, "Gemfile")}
      expect(system(environment, "bundle", "exec", "standardrb", "--config", ".standard.yml", "--raise-cop-error", "clean.rb", chdir: target)).to be(true)
      output, status = Open3.capture2e(environment, "bundle", "exec", "standardrb", "--config", ".standard.yml", "--raise-cop-error", "violation.rb", chdir: target)
      expect(status.success?).to be(false)
      expect(output).to include("AntiSlop/NoInterpolatedSql")
    end
  end

  def install_snapshot(target)
    expect(system("ruby", File.join(root, "scripts/install.rb"), target)).to be(true)
  end

  def standard_plugin_config
    <<~YAML
      plugins:
        - anti_slop_ror:
            require_path: tools/anti_slop_ror/lib/anti_slop_ror/plugin
            plugin_class_name: AntiSlopRor::Plugin
    YAML
  end
end
