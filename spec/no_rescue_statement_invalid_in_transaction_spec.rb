require "spec_helper"

RSpec.describe RuboCop::Cop::AntiSlop::NoRescueStatementInvalidInTransaction do
  it "flags swallowed statement invalid inside a transaction" do
    expect_offense(<<~RUBY)
      ApplicationRecord.transaction do
        write
      rescue ActiveRecord::StatementInvalid
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRescueStatementInvalidInTransaction: Do not swallow ActiveRecord::StatementInvalid inside a transaction; re-raise it.
        false
      end
    RUBY
  end

  it "allows re-raise and rescues outside transactions" do
    expect_no_offenses("ApplicationRecord.transaction { write rescue ActiveRecord::StatementInvalid; raise }")
    expect_no_offenses("write rescue ActiveRecord::StatementInvalid; false")
  end
end
