require "rubocop"
require "rubocop/rspec/support"
require "anti_slop_ror"

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense
end

RSpec.shared_context "anti slop cop" do
  let(:config) { RuboCop::Config.new }
  subject(:cop) { described_class.new(config) }
end

RSpec.configure do |config|
  config.include_context "anti slop cop"
end
