module RuboCop
  module Cop
    module AntiSlop
      class NoRescueStatementInvalidInTransaction < Base
        MSG = "Do not swallow ActiveRecord::StatementInvalid inside a transaction; re-raise it."

        def on_resbody(node)
          return unless rescues_statement_invalid?(node.exceptions) && in_transaction?(node) && !re_raises?(node.body)
          add_offense(node)
        end

        private

        def rescues_statement_invalid?(exceptions)
          return true if exceptions.nil? || exceptions.empty?

          exceptions.any? do |exception|
            exception.const_type? && %w[ActiveRecord::StatementInvalid ActiveRecord::ActiveRecordError StandardError Exception].include?(exception.const_name)
          end
        end

        def in_transaction?(node)
          node.each_ancestor(:block).any? { |ancestor| ancestor.send_node.method_name == :transaction }
        end
      end
    end
  end
end
