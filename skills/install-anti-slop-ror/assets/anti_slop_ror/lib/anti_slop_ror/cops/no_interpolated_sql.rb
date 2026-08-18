module RuboCop
  module Cop
    module AntiSlop
      class NoInterpolatedSql < Base
        MSG = "Do not build SQL with interpolation or string concatenation. Use binds or sanitization."
        SQL_METHODS = %i[where having joins left_joins order group select from find_by_sql exec_query execute].freeze

        def on_send(node)
          return unless SQL_METHODS.include?(node.method_name) || arel_sql?(node)
          sql = node.arguments.first
          return if sanitized?(sql) || placeholder_with_binds?(node)
          add_offense(sql) if dynamic_sql?(sql)
        end

        private

        def arel_sql?(node)
          node.method_name == :sql && node.receiver&.const_name == "Arel"
        end

        def dynamic_sql?(node)
          node&.dstr_type? || node&.send_type? && node.method_name == :+
        end

        def sanitized?(node)
          node&.send_type? && node.method_name == :sanitize_sql_array
        end

        def placeholder_with_binds?(node)
          node.arguments.length > 1 && node.arguments.first&.str_type? && node.arguments.first.value.match?(/[?:]/)
        end
      end
    end
  end
end
