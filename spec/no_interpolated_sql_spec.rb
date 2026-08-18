require "spec_helper"

RSpec.describe RuboCop::Cop::AntiSlop::NoInterpolatedSql do
  it "flags constructed SQL" do
    expect_offense(<<~RUBY)
      User.where("name = '\#{params[:name]}'")
                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoInterpolatedSql: Do not build SQL with interpolation or string concatenation. Use binds or sanitization.
    RUBY
  end

  it "allows literals, hashes, binds, and sanitized arrays" do
    expect_no_offenses("User.where(name: params[:name])")
    expect_no_offenses("User.where('name = ?', params[:name])")
    expect_no_offenses("User.where(sanitize_sql_array(['name = ?', params[:name]]))")
  end
end
