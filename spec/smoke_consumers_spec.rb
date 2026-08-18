require "spec_helper"
require "open3"
require "tmpdir"
require_relative "../scripts/smoke_consumers"

RSpec.describe "smoke consumer bundle environment" do
  it "derives the configured project bundle root through Bundler" do
    allow(Bundler).to receive(:settings).and_return({"path" => "/tmp/project-bundle"})
    expect(project_bundle_path).to eq("/tmp/project-bundle")
  end

  it "uses a configured bundle path without inheriting the root Gemfile binding" do
    expect(bundle_environment(bundle_path: "/tmp/project-bundle")).to eq(
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_PATH" => "/tmp/project-bundle",
      "BUNDLE_DEPLOYMENT" => nil,
      "BUNDLE_FROZEN" => nil
    )
  end

  it "leaves bundle path unset when the project uses system gems" do
    Dir.mktmpdir do |target|
      File.write(File.join(target, "Gemfile"), "source \"https://rubygems.org\"\n")
      output, status = Open3.capture2e(bundle_environment(bundle_path: nil), "bundle", "config", "get", "path", chdir: target)
      expect(status.success?).to be(true)
      expect(output).to include("You have not configured a value for `path`")
    end
  end
end
