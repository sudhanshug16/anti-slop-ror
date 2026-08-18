#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

target = ARGV.fetch(0) { abort "usage: #{$PROGRAM_NAME} TARGET" }
source = File.expand_path("../skills/install-anti-slop-ror/assets/anti_slop_ror", __dir__)
destination = File.join(File.expand_path(target), "tools/anti_slop_ror")
abort "refusing to overwrite existing #{destination}" if File.exist?(destination)
FileUtils.mkdir_p(File.dirname(destination))
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
