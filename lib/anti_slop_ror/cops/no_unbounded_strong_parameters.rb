module RuboCop
  module Cop
    module AntiSlop
      class NoUnboundedStrongParameters < Base
        MSG = "Do not permit an unbounded parameter shape. Declare its allowed keys."

        def on_send(node)
          add_offense(node) if node.method_name == :permit!
          return unless %i[permit expect].include?(node.method_name)

          node.arguments.each do |argument|
            next unless argument.hash_type?
            argument.pairs.each do |pair|
              next unless empty_hash?(pair.value)
              next if allowed_key?(pair.key)

              add_offense(pair.value)
            end
          end
        end

        alias_method :on_csend, :on_send

        private

        def allowed_key?(key)
          key_name = (key.sym_type? || key.str_type?) ? key.value.to_s : nil
          Array(cop_config["AllowedKeys"]).map(&:to_s).include?(key_name)
        end
      end
    end
  end
end
