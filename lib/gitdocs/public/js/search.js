GitDocs.search = {
  highlight : function(query) {
    $('.results dl dd').each(function(idx, el) {
      var result = $(el).text().replace(query, "<strong>" + query + "</strong>");
      $(el).html(result)
    });
  }
};

$(document).ready(function() {
  var query = $('.results').data("query");
  GitDocs.search.highlight(query);
});