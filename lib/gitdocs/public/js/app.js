GitDocs = {
  // Links all breadcrumb options in the explored path
  linkBreadcrumbs : function() {
    var fullPath = $('span.path').text();
    var paths = fullPath.split("/");
    var docIdx = window.location.pathname.match(/(\d+)\//);
    if (!docIdx) return false;
    $(paths).each(function(idx, subpath) {
      var relPath = paths.slice(0, idx+1).join("/");
      var link = "<a href='/" + docIdx[1] + relPath + "'>" + subpath + "/</a>";
      fullPath = fullPath.replace(subpath + "/", link);
    });
    $('span.path').html(fullPath);
  },
  // fills in directory meta author and modified for every file
  fillDirMeta : function(){
    $('table.listing tbody tr').each(function(i, e) {
      var file = $(e).find('a').attr('href');
      $.getJSON(file + "?mode=meta", function(data) {
        $(e).find('td.author').html(data.author);
        $(e).find('td.modified').html(RelativeDate.time_ago_in_words(data.modified));
      });
    });
  }
};

$(document).ready(function() {
  GitDocs.linkBreadcrumbs();
  GitDocs.fillDirMeta();
  StringFormatter.autoLink();
});

// Redirect to edit page for new file when new file form is submitted
$('form.add').live('submit', function(e){
  var docIdx = window.location.pathname.match(/(\d+)\//);
  var fullPath = $('span.path').text();
  window.location = "/" + docIdx[1] + fullPath + "/" + $(this).find('input.edit').val();
  e.preventDefault();
});
