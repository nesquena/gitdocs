GitDocs.settings = {
  // To make the settings form ajax-y
  observeSettingsForm : function() {
    $('#settings').submit(function(e) {
      e.preventDefault();
      $.ajax({
        type: 'POST', url: this.action, data: $(this).serialize(),
        success: function() {
          GitDocs.showAlert(
            '<p><strong>Settings saved!</strong> Gitdocs has been restarted with your new settings.</p>',
            'success'
          );
        }
      });
      return false;
    });
  }
};

$(document).ready(function() {
  GitDocs.settings.observeSettingsForm();
});

// Handle delete for settings form
$('input.remove_share').live('click', function(e){
  $(this).siblings("input[type=hidden]").val("true");
  $(this).parents("form").submit();
});
