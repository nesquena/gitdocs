$(document).ready(function() {
  var editor = ace.edit("editor");
  var textarea = $('form.edit textarea#data').hide();
  var filename = $('form.edit input.filename').val();
  editor.setTheme("ace/theme/tomorrow_night");
  
  // Sync with textarea
  editor.getSession().setValue(textarea.val());
  editor.getSession().on('change', function(){
    textarea.val(editor.getSession().getValue());
  });
  
  // Define languages
  var langMode = {};
  var langMap  = { 'rb' : 'ruby', 'js' : 'javascript', 'css' : 'css', 'md' : 'markdown', 'html' : 'html' };
  $(Utils.getValues(langMap)).each(function(idx, lang) {
    langMode[lang] = require("ace/mode/" + lang).Mode;
  });
  
  // Apply code highlighting mode based on map
  $.each(langMap, function(ext, name) {
    if (filename.match(ext)) { editor.getSession().setMode(new langMode[name]); }
  });

  // Display ace editor
  $('form.edit').show();
});