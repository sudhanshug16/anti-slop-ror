require "spec_helper"

RSpec.describe RuboCop::Cop::AntiSlop::NoUnsafeRedirectFromRequest do
  it "flags request controlled external redirects" do
    expect_offense(<<~RUBY)
      redirect_to params[:next], allow_other_host: true
                  ^^^^^^^^^^^^^ AntiSlop/NoUnsafeRedirectFromRequest: Do not redirect to a request-controlled target with allow_other_host: true.
    RUBY
  end

  it "flags request controlled external redirects through safe navigation" do
    expect_offense(<<~RUBY)
      controller&.redirect_to(params[:next], allow_other_host: true)
                              ^^^^^^^^^^^^^ AntiSlop/NoUnsafeRedirectFromRequest: Do not redirect to a request-controlled target with allow_other_host: true.
    RUBY
  end

  it "flags literal keyword splats" do
    expect_offense(<<~RUBY)
      redirect_to params[:next], **{allow_other_host: true}
                  ^^^^^^^^^^^^^ AntiSlop/NoUnsafeRedirectFromRequest: Do not redirect to a request-controlled target with allow_other_host: true.
    RUBY
  end

  it "allows literals and url_from" do
    expect_no_offenses("redirect_to 'https://example.test', allow_other_host: true")
    expect_no_offenses("redirect_to url_from(params[:next]), allow_other_host: true")
    expect_no_offenses("redirect_to params[:next], **options")
  end
end
