GitDocs.search = {
  highlight : function(query) {
    $('.results dl dd').each(function(idx, el) {
      var result = $(el).text().replace(new RegExp(query, 'ig'), function($0) { return"<strong>" + $0 + "</strong>"; });
      $(el).html(result);
    });
  }
};

$(document).ready(function() {
  var query = $('.results').data("query");
  GitDocs.search.highlight(query);
});