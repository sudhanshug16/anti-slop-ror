module RuboCop
  module Cop
    module AntiSlop
      class NoUnsafeRedirectFromRequest < Base
        MSG = "Do not redirect to a request-controlled target with allow_other_host: true."

        def on_send(node)
          return unless node.method_name == :redirect_to
          target = node.arguments.first
          options = node.arguments.find(&:hash_type?)
          return unless options && allow_other_host?(options) && request_value?(target)
          return if target&.send_type? && target.method_name == :url_from

          add_offense(target)
        end

        private

        def allow_other_host?(hash)
          pairs = hash.children.flat_map do |item|
            (item.kwsplat_type? && item.children.first&.hash_type?) ? item.children.first.pairs : [item]
          end
          pair = pairs.find { |item| item.pair_type? && item.key.sym_type? && item.key.value == :allow_other_host }
          pair&.value&.true_type?
        end
      end
    end
  end
end
