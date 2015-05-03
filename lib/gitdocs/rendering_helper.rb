# -*- encoding : utf-8 -*-

require 'redcarpet'
require 'coderay'
require 'tilt'

module Gitdocs
  module RenderingHelper
    # @param [String, nil] pathname
    #
    # @return [nil] if the pathname is nil
    # @return [String]
    def file_content_render(pathname)
      return unless pathname

      tilt = Tilt.new(
        pathname,
        1, # line number
        fenced_code_blocks: true,
        renderer:           CodeRayify.new(filter_html: true, hard_wrap: true)
      )
      %(<div class="tilt">#{tilt.render}</div>)
    rescue LoadError, RuntimeError # No tilt support
      if path.text?
        code_ray = CodeRay.scan_file(pathname)
        %(<pre class="CodeRay">#{code_ray.encode(:html)}</pre>)
      else
        %(<embed class="inline-file" src="#{request.path_info}?mode=raw"></embed>)
      end
    end

    class CodeRayify < ::Redcarpet::Render::Safe
      # Override the safe #block_code with CodeRay, if a language is present.
      #
      # @param [String] code
      # @param [String] langauge
      #
      # @return [String]
      def block_code(code, language)
        if language
          CodeRay.scan(code, language).div
        else
          super(code, language)
        end
      end
    end
  end
end
