require "spec_helper"
require "open3"
require "rbconfig"
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

  it "resolves a locally installed gem from a configured bundle path outside the project cwd" do
    Dir.mktmpdir("smoke-bundle") do |bundle_path|
      Dir.mktmpdir("smoke-gem") do |gem_source|
        build_fixture_gem(gem_source)
        install_fixture_gem(gem_source, bundle_path)
        Dir.mktmpdir("smoke-consumer") do |consumer|
          File.write(File.join(consumer, "Gemfile"), "source \"https://rubygems.org\"\ngem \"smoke-consumer-fixture\", \"1.0.0\"\n")
          output, status = Open3.capture2e(bundle_environment(bundle_path: bundle_path), "bundle", "lock", "--local", chdir: consumer)
          expect(status.success?).to be(true), output
          expect(File.read(File.join(consumer, "Gemfile.lock"))).to include("smoke-consumer-fixture (1.0.0)")
        end
      end
    end
  end

  def build_fixture_gem(source)
    FileUtils.mkdir_p(File.join(source, "lib"))
    File.write(File.join(source, "lib/smoke_consumer_fixture.rb"), "module SmokeConsumerFixture\nend\n")
    File.write(File.join(source, "smoke-consumer-fixture.gemspec"), fixture_gemspec)
    output, status = Open3.capture2e("gem", "build", "smoke-consumer-fixture.gemspec", chdir: source)
    expect(status.success?).to be(true), output
  end

  def install_fixture_gem(source, bundle_path)
    install_directory = File.join(bundle_path, "ruby", RbConfig::CONFIG.fetch("ruby_version"))
    output, status = Open3.capture2e("gem", "install", "--local", "--install-dir", install_directory, "--no-document", "smoke-consumer-fixture-1.0.0.gem", chdir: source)
    expect(status.success?).to be(true), output
  end

  def fixture_gemspec
    <<~RUBY
      Gem::Specification.new do |spec|
        spec.name = "smoke-consumer-fixture"
        spec.version = "1.0.0"
        spec.summary = "Temporary smoke fixture"
        spec.authors = ["Test"]
        spec.files = ["lib/smoke_consumer_fixture.rb"]
      end
    RUBY
  end
end
