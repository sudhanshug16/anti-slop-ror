module RuboCop
  module Cop
    module AntiSlop
      class NoRescueStatementInvalidInTransaction < Base
        MSG = "Do not swallow ActiveRecord::StatementInvalid inside a transaction; re-raise it."

        def on_resbody(node)
          return unless statement_invalid?(node.exceptions) && in_transaction?(node) && !re_raises?(node.body)
          add_offense(node)
        end

        private

        def statement_invalid?(exceptions)
          exceptions.any? { |exception| exception.const_type? && exception.const_name == "ActiveRecord::StatementInvalid" }
        end

        def in_transaction?(node)
          node.each_ancestor(:block).any? { |ancestor| ancestor.send_node.method_name == :transaction }
        end
      end
    end
  end
end
