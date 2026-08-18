#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

root = File.expand_path("..", __dir__)
source_root = root
asset_root = File.join(root, "skills/install-anti-slop-ror/assets/anti_slop_ror")
files = %w[lib config]
expected = files.flat_map do |directory|
  Dir.glob(File.join(source_root, directory, "**", "*")).select { |path| File.file?(path) }.map { |path| path.delete_prefix("#{source_root}/") }
end
actual = Dir.glob(File.join(asset_root, "**", "*")).select { |path| File.file?(path) }.map { |path| path.delete_prefix("#{asset_root}/") }
drift = (expected | actual).select do |relative|
  !expected.include?(relative) || !actual.include?(relative) || File.binread(File.join(source_root, relative)) != File.binread(File.join(asset_root, relative))
end

if ARGV == ["--check"]
  abort "skill assets drift: #{drift.join(", ")}" unless drift.empty?
  puts "skill assets are synchronized"
  exit
end

abort "usage: #{$PROGRAM_NAME} [--check]" unless ARGV.empty?
FileUtils.rm_rf(asset_root)
expected.each do |relative|
  destination = File.join(asset_root, relative)
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.cp(File.join(source_root, relative), destination)
end
puts "synchronized #{expected.length} skill assets"
