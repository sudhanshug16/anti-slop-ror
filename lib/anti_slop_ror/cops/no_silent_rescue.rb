module RuboCop
  module Cop
    module AntiSlop
      class NoSilentRescue < Base
        MSG = "Do not silently suppress an exception. Log, report, return an explicit value, or re-raise."

        def on_resbody(node)
          body = node.body
          add_offense(node) if body.nil? || body.nil_type?
        end
      end
    end
  end
end
