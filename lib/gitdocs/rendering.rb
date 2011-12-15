# This shouldn't exist but I can't find any other way to prevent redcarpet from complaining
# WARN: tilt autoloading 'redcarpet' in a non thread-safe way; explicit require 'redcarpet' suggested.
# !! Unexpected error while processing request: Input must be UTF-8 or US-ASCII, ASCII-8BIT given
# Input must be UTF-8 or US-ASCII, ASCII-8BIT given
#   gems/redcarpet-2.0.1/lib/redcarpet.rb:70:in `render'
#   gems/redcarpet-2.0.1/lib/redcarpet.rb:70:in `to_html'
#   gems/tilt-1.3.3/lib/tilt/markdown.rb:38:in `evaluate'
#   gems/tilt-1.3.3/lib/tilt/markdown.rb:61:in `evaluate'
#   gems/tilt-1.3.3/lib/tilt/template.rb:76:in `render'

require 'redcarpet'

# Compatibility class;
# Creates a instance of Redcarpet with the RedCloth
# API. This instance has no extensions enabled whatsoever,
# and no accessors to change this. 100% pure, standard
# Markdown.
class RedcarpetCompat
  def to_html(*_dummy)
    @markdown.render(@text.encode('utf-8'))
  end
end