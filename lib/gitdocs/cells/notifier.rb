# -*- encoding : utf-8 -*-

module Gitdocs
  module Cells
    # Wrapper for the Notiffany notification library
    class Notifier
      include Celluloid
      finalizer :my_finalizer

      # @param [String] title
      # @param [String] message
      # @param [:success,:pending,:failed] type
      #
      # @return [void]
      def notify
        @notifier ||= Notiffany.connect
        @notifier.notify(message, title: :title, image: type)
      end

      def my_finalizer
        @notifier.disconnect if @notifier
        @notifier = nil
      end
    end
  end
end
