require "spec_helper"

RSpec.describe RuboCop::Cop::AntiSlop::NoRequestDrivenDynamicDispatch do
  it "flags direct parameter dispatch" do
    expect_offense(<<~RUBY)
      handler.public_send(params[:action])
                          ^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
    RUBY
  end

  it "allows literals and an explicit mapping" do
    expect_no_offenses("handler.public_send(:call)")
    expect_no_offenses("HANDLERS.fetch(params[:kind]).call")
  end
end
