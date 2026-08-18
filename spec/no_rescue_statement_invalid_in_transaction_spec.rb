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

  it "flags broad rescues that can swallow statement invalid" do
    expect_offense(<<~RUBY)
      ApplicationRecord.transaction do
        write
      rescue
      ^^^^^^ AntiSlop/NoRescueStatementInvalidInTransaction: Do not swallow ActiveRecord::StatementInvalid inside a transaction; re-raise it.
        false
      end
      ApplicationRecord.transaction do
        write
      rescue StandardError
      ^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRescueStatementInvalidInTransaction: Do not swallow ActiveRecord::StatementInvalid inside a transaction; re-raise it.
        false
      end
      ApplicationRecord.transaction do
        write
      rescue Exception
      ^^^^^^^^^^^^^^^^ AntiSlop/NoRescueStatementInvalidInTransaction: Do not swallow ActiveRecord::StatementInvalid inside a transaction; re-raise it.
        false
      end
      ApplicationRecord.transaction do
        write
      rescue ActiveRecord::ActiveRecordError
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AntiSlop/NoRescueStatementInvalidInTransaction: Do not swallow ActiveRecord::StatementInvalid inside a transaction; re-raise it.
        false
      end
    RUBY
  end

  it "allows re-raise and rescues outside transactions" do
    expect_no_offenses("ApplicationRecord.transaction do\n  write\nrescue ActiveRecord::StatementInvalid\n  raise\nend")
    expect_no_offenses("write rescue ActiveRecord::StatementInvalid; false")
  end
end
