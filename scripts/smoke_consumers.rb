#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "rubygems/package"
require "tmpdir"
require "bundler"

ROOT = File.expand_path("..", __dir__)
INSTALLER = File.join(ROOT, "skills/install-anti-slop-ror/scripts/install.rb")

def project_bundle_path
  # BUNDLE_PATH expects Bundler's configured root, not bundle_path (which appends ruby/version).
  Bundler.settings["path"]
end

def bundle_environment(bundle_path: project_bundle_path)
  environment = {
    "BUNDLE_GEMFILE" => nil,
    "BUNDLE_DEPLOYMENT" => nil,
    "BUNDLE_FROZEN" => nil
  }
  environment["BUNDLE_PATH"] = bundle_path if bundle_path
  environment
end

def run!(*command, chdir:)
  output, status = Open3.capture2e(bundle_environment, *command, chdir: chdir)
  abort "#{command.join(" ")} failed:\n#{output}" unless status.success?
  output
end

def write_consumer_gemfile(target, gem_line: nil)
  contents = ["source \"https://rubygems.org\"", "gem \"standard\", \">= 1.35\"", "gem \"lint_roller\", \">= 1.1\"", gem_line].compact.join("\n")
  File.write(File.join(target, "Gemfile"), "#{contents}\n")
  run!("bundle", "lock", "--local", chdir: target)
end

def build_packaged_gem!(target)
  package = File.join(target, "anti-slop-ror.gem")
  unpacked = File.join(target, "unpacked")
  run!("gem", "build", File.join(ROOT, "anti-slop-ror.gemspec"), "--output", package, chdir: ROOT)
  run!("gem", "unpack", package, "--target", unpacked, chdir: target)
  source = Dir[File.join(unpacked, "anti-slop-ror*")].select { |path| File.directory?(path) }
  abort "expected one unpacked anti-slop-ror gem, found #{source.length}" unless source.one?

  specification = Gem::Package.new(package).spec
  File.write(File.join(source.first, "#{specification.name}.gemspec"), specification.to_ruby)

  source.first
end

def verify_consumer!(target, config)
  File.write(File.join(target, ".standard.yml"), config)
  File.write(File.join(target, "clean.rb"), "User.where(name: params[:name])\n")
  File.write(File.join(target, "violation.rb"), "User.where(\"name = '\#{params[:name]}'\")\n")
  run!("bundle", "exec", "standardrb", "--config", ".standard.yml", "--raise-cop-error", "clean.rb", chdir: target)
  output, status = Open3.capture2e(bundle_environment, "bundle", "exec", "standardrb", "--config", ".standard.yml", "--raise-cop-error", "violation.rb", chdir: target)
  abort "violating consumer unexpectedly passed" if status.success?
  abort "expected AntiSlop offense:\n#{output}" unless output.include?("AntiSlop/NoInterpolatedSql")
end

if $PROGRAM_NAME == __FILE__
  Dir.mktmpdir("anti-slop-ror-vendored") do |target|
    write_consumer_gemfile(target)
    run!("ruby", INSTALLER, target, chdir: ROOT)
    verify_consumer!(target, <<~YAML)
      plugins:
        - anti_slop_ror:
            require_path: tools/anti_slop_ror/lib/anti_slop_ror/plugin
            plugin_class_name: AntiSlopRor::Plugin
    YAML
  end

  Dir.mktmpdir("anti-slop-ror-package") do |target|
    packaged_gem = build_packaged_gem!(target)
    consumer = File.join(target, "consumer")
    FileUtils.mkdir_p(consumer)
    write_consumer_gemfile(consumer, gem_line: "gem \"anti-slop-ror\", path: #{packaged_gem.inspect}")
    verify_consumer!(consumer, "plugins:\n  - anti-slop-ror\n")
  end

  puts "isolated vendored and packaged-gem StandardRB consumer smokes passed"
end
