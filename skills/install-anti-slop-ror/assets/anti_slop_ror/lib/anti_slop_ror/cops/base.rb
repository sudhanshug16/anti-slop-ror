module RuboCop
  module Cop
    module AntiSlop
      class Base < RuboCop::Cop::Base
        private

        def request_value?(node)
          return false unless node
          return true if node.send_type? && node.method_name == :params
          return true if node.send_type? && node.receiver&.send_type? && node.receiver.method_name == :request && %i[parameters query_parameters request_parameters].include?(node.method_name)

          node.each_descendant.any? { |child| request_value?(child) }
        end

        def empty_hash?(node)
          node&.hash_type? && node.pairs.empty?
        end

        def re_raises?(node)
          node && (node.send_type? && node.method_name == :raise || node.each_descendant.any? { |child| child.send_type? && child.method_name == :raise })
        end
      end
    end
  end
end
