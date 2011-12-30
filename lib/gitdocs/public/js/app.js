GitDocs = {
  // Links all breadcrumb options in the explored path
  linkBreadcrumbs : function() {
    var fullPath = $('span.path').text().replace(/\/+/g, '/').replace(/\/$/, '');
    if (fullPath.length == 0) { return; }
    var docIdx = window.location.pathname.match(/\/(\d+)/);
    if (!docIdx) return false;
    var paths = fullPath.split("/");
    $(paths).each(function(idx, subpath) {
      var relPath = paths.slice(0, idx+1).join("/");
      var link = "<a href='/" + docIdx[1] + relPath + "'>" + subpath + "/</a>";
      fullPath = fullPath.replace(subpath + "/", link);
    });
    $('span.path').html(fullPath);
  },
  // fills in directory meta author and modified for every file
  fillDirMeta : function(){
    $('table#fileListing tbody tr').each(function(i, e) {
      var file = $(e).find('a').attr('href');
      var fileListingBody = $('table#fileListing tbody')
      $.getJSON(file + "?mode=meta", function(data) {
        $(e).addClass('loaded').find('td.author').html(data.author);
        $(e).find('td.modified').html(RelativeDate.time_ago_in_words(data.modified));
        $(e).find('td.size').html(Utils.humanizeBytes(data.size)).data("val", data.size);
        if ($(fileListingBody).find('tr').length == $(fileListingBody).find('tr.loaded').length) {
          GitDocs.pageLoaded(); // Fire on completion
        }
      });
    });
  },
  // Fire when the page is finished loading
  pageLoaded : function() {
    // Enable table sorter
    var extractor = function(e) { return $(e).data('val') || $(e).text() }
    $("table#fileListing").tablesorter({ textExtraction : extractor, sortList: [[0,0]] });
  },
  // To make the settings form ajax-y
  observeSettingsForm : function() {
    $('#settings').submit(function(e) {
      e.preventDefault();
      $.ajax({
        type: 'POST',
        url: this.action,
        data: $(this).serialize(),
        success: function() {
          var el = $('.content').prepend('<div class="alert-message success"><a class="close" href="#">×</a>' +
          '<p><strong>Settings saved!</strong> Gitdocs has been restarted with your new settings.</p>' +
          '</div>');
          $('div.alert-message').alert();
        }
      });
      return false;
    });
  }
};

$(document).ready(function() {
  GitDocs.linkBreadcrumbs();
  GitDocs.fillDirMeta();
  StringFormatter.autoLink();
  GitDocs.observeSettingsForm();
});

// Redirect to edit page for new file when new file form is submitted
$('form.add').live('submit', function(e){
  var docIdx = window.location.pathname.match(/\/(\d+)/);
  if (!docIdx) return false;
  var fullPath = $('span.path').text();
  var newPath = "/" + docIdx[1] + (fullPath == "/" ? "/" : fullPath + "/") + $(this).find('input.edit').val();
  window.location = newPath;
  e.preventDefault(); return false;
});

// Link method redirection
$('a[data-method]').live('click', function(e) {
  e.preventDefault();
  var link = $(this);
  var href = link.attr('href'),
    method = link.data('method'),
    target = link.attr('target'),
    form = $('<form method="post" action="' + href + '"></form>'),
    metadata_input = '<input name="_method" value="' + method + '" type="hidden" />';
  if (target) { form.attr('target', target); }
  form.hide().append(metadata_input).appendTo('body');
  form.submit();
});