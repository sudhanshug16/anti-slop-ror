module RuboCop
  module Cop
    module AntiSlop
      class Base < RuboCop::Cop::Base
        private

        def request_value?(node)
          return false unless node
          return true if request_accessor?(node)

          node.each_descendant.any? { |child| request_value?(child) }
        end

        def call_node?(node)
          node&.send_type? || node&.csend_type?
        end

        def request_accessor?(node)
          return false unless call_node?(node)
          return true if node.method_name == :params && implicit_or_request_receiver?(node.receiver)

          request_receiver?(node.receiver) && %i[params parameters path_parameters query_parameters request_parameters].include?(node.method_name)
        end

        def implicit_or_request_receiver?(node)
          node.nil? || node.self_type? || request_receiver?(node)
        end

        def request_receiver?(node)
          call_node?(node) && node.method_name == :request && (node.receiver.nil? || node.receiver.self_type?)
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
