require "spec_helper"

RSpec.describe RuboCop::Cop::AntiSlop::NoRequestDrivenDynamicDispatch do
  it "flags direct parameter dispatch" do
    expect_offense(<<~RUBY)
      handler.public_send(params[:action])
                          ^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
    RUBY
  end

  it "flags safe-navigation dispatch from request sources" do
    expect_offense(<<~RUBY)
      handler&.public_send(request.path_parameters[:action])
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
    RUBY
  end

  it "allows literals and an explicit mapping" do
    expect_no_offenses("handler.public_send(:call)")
    expect_no_offenses("handler.public_send(HANDLERS.fetch(params[:kind]))")
  end

  it "recognizes request sources without treating arbitrary params methods as sources" do
    expect_no_offenses("handler.public_send(logger.params)")
    expect_no_offenses("handler.public_send(domain_object.params)")
    expect_offense(<<~RUBY)
      handler.public_send(self.params[:action])
                          ^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
      handler.public_send(request.params[:action])
                          ^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
      handler.public_send(request.request_parameters[:action])
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
      handler.public_send(request.query_parameters[:action])
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
      handler.public_send(request.parameters[:action])
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRequestDrivenDynamicDispatch: Do not dispatch a method or constant directly from request parameters.
    RUBY
  end
end
