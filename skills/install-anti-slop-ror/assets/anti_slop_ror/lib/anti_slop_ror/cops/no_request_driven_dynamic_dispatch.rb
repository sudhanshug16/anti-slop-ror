module RuboCop
  module Cop
    module AntiSlop
      class NoRequestDrivenDynamicDispatch < Base
        MSG = "Do not dispatch a method or constant directly from request parameters."
        DISPATCH = %i[send public_send const_get constantize safe_constantize].freeze

        def on_send(node)
          return unless DISPATCH.include?(node.method_name)
          name = node.arguments.first
          return unless request_value?(name)
          return if closed_mapping_lookup?(name)

          add_offense(name)
        end

        alias_method :on_csend, :on_send

        private

        def closed_mapping_lookup?(node)
          node&.send_type? && %i[fetch []].include?(node.method_name) && node.receiver&.const_type?
        end
      end
    end
  end
end
