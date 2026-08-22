require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "vendored assets" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:skill) { File.join(root, "skills/install-anti-slop-ror") }
  let(:skill_installer) { File.join(skill, "scripts/install.rb") }

  it "has no asset drift" do
    expect(system("ruby", "scripts/sync_skill_assets.rb", "--check", chdir: root)).to be(true)
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

  it "installs from a standalone copy of the skill" do
    Dir.mktmpdir do |temporary_root|
      standalone_skill = File.join(temporary_root, "install-anti-slop-ror")
      target = File.join(temporary_root, "target")
      FileUtils.cp_r(skill, standalone_skill)
      FileUtils.mkdir_p(target)

      output, status = Open3.capture2e("ruby", File.join(standalone_skill, "scripts/install.rb"), target)

      expect(status).to be_success
      expect(File).to exist(File.join(target, "tools/anti_slop_ror/config/default.yml"))
      expect(File).to exist(File.join(target, "tools/anti_slop_ror/lib/anti_slop_ror/plugin.rb"))
      expect(output).to include("Installed bundled snapshot")
    end
  end

  it "refuses an existing snapshot unless force is explicit" do
    Dir.mktmpdir do |target|
      install_snapshot(target)
      expect(system("ruby", File.join(root, "scripts/install.rb"), target)).to be(false)
      expect(system("ruby", File.join(root, "scripts/install.rb"), "--force", target)).to be(true)
    end
  end

  it "rejects a missing target directory" do
    missing = File.join(Dir.mktmpdir, "missing")
    expect(system("ruby", File.join(root, "scripts/install.rb"), missing)).to be(false)
  end

  def install_snapshot(target)
    expect(system("ruby", skill_installer, target)).to be(true)
  end
end
