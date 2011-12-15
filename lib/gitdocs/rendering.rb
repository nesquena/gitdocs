# This shouldn't exist but I can't find any other way to prevent redcarpet from complaining

require 'redcarpet'
class RedcarpetCompat
  def to_html(*_dummy)
    @markdown.render(@text.force_encoding('utf-8'))
  end
end