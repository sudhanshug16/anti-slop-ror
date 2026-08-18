require "rubocop"
require "anti_slop_ror/version"
require "anti_slop_ror/plugin"
require "anti_slop_ror/cops/base"
Dir[File.join(__dir__, "anti_slop_ror/cops/*.rb")].sort.each { |file| require file }
