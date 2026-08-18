#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

force = ARGV.delete("--force")
abort "usage: #{$PROGRAM_NAME} [--force] TARGET" unless ARGV.one?
target = File.expand_path(ARGV.first)
abort "target must be an existing directory: #{target}" unless File.directory?(target)
source = File.expand_path("../skills/install-anti-slop-ror/assets/anti_slop_ror", __dir__)
destination = File.join(target, "tools/anti_slop_ror")
abort "refusing to overwrite existing #{destination}; rerun with --force to replace this snapshot" if File.exist?(destination) && !force
FileUtils.mkdir_p(File.dirname(destination))
FileUtils.rm_rf(destination) if File.exist?(destination)
FileUtils.cp_r(source, destination)
puts "Installed snapshot to #{destination}"
puts <<~YAML
  Add this to .standard.yml:
  plugins:
    - anti_slop_ror:
        require_path: tools/anti_slop_ror/lib/anti_slop_ror/plugin
        plugin_class_name: AntiSlopRor::Plugin
YAML
puts "Verify (blocking): bundle exec standardrb --raise-cop-error"
