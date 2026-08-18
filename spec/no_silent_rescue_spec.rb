require "spec_helper"

RSpec.describe RuboCop::Cop::AntiSlop::NoSilentRescue do
  it "flags empty and nil rescue bodies" do
    expect_offense("begin\n  work\nrescue\n^^^^^^ AntiSlop/NoSilentRescue: Do not silently suppress an exception. Log, report, return an explicit value, or re-raise.\nend\n")
    expect_offense(<<~RUBY)
      work rescue nil
           ^^^^^^^^^^ AntiSlop/NoSilentRescue: Do not silently suppress an exception. Log, report, return an explicit value, or re-raise.
    RUBY
  end

  it "allows explicit handling" do
    expect_no_offenses("work rescue false")
    expect_no_offenses("work rescue report_error")
    expect_no_offenses("work rescue raise")
  end
end
