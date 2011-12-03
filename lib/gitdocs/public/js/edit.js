$(document).ready(function() {
  var editor = ace.edit("editor");
  var textarea = $('form.edit textarea#data').hide();
  editor.setTheme("ace/theme/twilight");
  editor.getSession().setValue(textarea.val());
  editor.getSession().on('change', function(){
    textarea.val(editor.getSession().getValue());
  });
  $('form.edit').show();
});