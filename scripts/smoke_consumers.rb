#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require "bundler"

ROOT = File.expand_path("..", __dir__)
INSTALLER = File.join(ROOT, "scripts/install.rb")

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

  Dir.mktmpdir("anti-slop-ror-gem") do |target|
    write_consumer_gemfile(target, gem_line: "gem \"anti-slop-ror\", path: #{ROOT.inspect}")
    verify_consumer!(target, "plugins:\n  - anti-slop-ror\n")
  end

  puts "isolated vendored and gem StandardRB consumer smokes passed"
end
