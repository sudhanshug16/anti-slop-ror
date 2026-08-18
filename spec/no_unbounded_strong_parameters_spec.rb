require "spec_helper"

RSpec.describe RuboCop::Cop::AntiSlop::NoUnboundedStrongParameters do
  let(:config) do
    RuboCop::Config.new("AntiSlop/NoUnboundedStrongParameters" => {"AllowedKeys" => ["metadata"]})
  end

  it "flags permit bang and empty contracts" do
    expect_offense("params.permit!\n^^^^^^^^^^^^^^ Do not permit an unbounded parameter shape. Declare its allowed keys.\n")
    expect_offense("params.expect(user: {})\n                    ^^ Do not permit an unbounded parameter shape. Declare its allowed keys.\n")
  end

  it "flags safe-navigation parameter contracts" do
    expect_offense("params&.permit!\n^^^^^^^^^^^^^^^ Do not permit an unbounded parameter shape. Declare its allowed keys.\n")
    expect_offense("params&.expect(user: {})\n                     ^^ Do not permit an unbounded parameter shape. Declare its allowed keys.\n")
  end

  it "allows a configured schemaless key and declared keys" do
    expect_no_offenses("params.permit(:name, settings: [:theme])")
    expect_no_offenses("params.expect(metadata: {})")
  end
end
