Utils = {
  getKeys : function(hash) {
    var keys = [];
    for(var i in hash) {
      keys.push(i);
    }
    return keys;
  },

  getValues : function(hash) {
    var values = [];
    for(var i in hash) {
      values.push(hash[i]);
    }
    return values;
  }
};

// DATES
// RelativeDate.time_ago_in_words(date)
var RelativeDate = {
  time_ago_in_words: function(from) {
          return RelativeDate.distance_of_time_in_words(new Date, RelativeDate.parseISO8601(from));

  },
  distance_of_time_in_words: function(to, from) {
      var distance_in_seconds = ((to - from) / 1000);
      var distance_in_minutes = Math.floor(distance_in_seconds / 60);

      if (distance_in_minutes <= 0) { return 'less than a minute ago'; }
      if (distance_in_minutes == 1) { return 'a minute ago'; }
      if (distance_in_minutes < 45) { return distance_in_minutes + ' minutes ago'; }
      if (distance_in_minutes < 120) { return '1 hour ago'; }
      if (distance_in_minutes < 1440) { return Math.floor(distance_in_minutes / 60) + ' hours ago'; }
      if (distance_in_minutes < 2880) { return '1 day ago'; }
      if (distance_in_minutes < 43200) { return Math.floor(distance_in_minutes / 1440) + ' days ago'; }
      if (distance_in_minutes < 86400) { return '1 month ago'; }
      if (distance_in_minutes < 525960) { return Math.floor(distance_in_minutes / 43200) + ' months ago'; }
      if (distance_in_minutes < 1051199) { return 'about 1 year ago'; }

      return 'over ' + Math.floor(distance_in_minutes / 525960) + ' years ago';
  },
  parseISO8601 : function(str) {
   // we assume str is a UTC date ending in 'Z'

   var parts = str.split('T'),
   dateParts = parts[0].split('-'),
   timeParts = parts[1].split('Z'),
   timeSubParts = timeParts[0].split(':'),
   timeSecParts = timeSubParts[2].split('.'),
   timeHours = Number(timeSubParts[0]),
   _date = new Date;

   _date.setUTCFullYear(Number(dateParts[0]));
   _date.setUTCMonth(Number(dateParts[1])-1);
   _date.setUTCDate(Number(dateParts[2]));
   _date.setUTCHours(Number(timeHours));
   _date.setUTCMinutes(Number(timeSubParts[1]));
   _date.setUTCSeconds(Number(timeSecParts[0]));
   if (timeSecParts[1]) _date.setUTCMilliseconds(Number(timeSecParts[1]));

   // by using setUTC methods the date has already been converted to local time(?)
   return _date;
  },
  humanize : function(str, shortened) {
    var parts = str.split('T')[0].split('-')
    var humDate = new Date;

    humDate.setFullYear(Number(parts[0]));
    humDate.setMonth(Number(parts[1])-1);
    humDate.setDate(Number(parts[2]));

    switch(humDate.getDay())
    {
    case 0:
      var day = "Sunday";
      break;
    case 1:
      var day = "Monday";
      break;
    case 2:
      var day = "Tuesday";
      break;
    case 3:
      var day = "Wednesday";
      break;
    case 4:
      var day = "Thursday";
      break;
    case 5:
      var day = "Friday";
      break;
    case 6:
      var day = "Saturday";
      break;
    }
    if(shortened) {
      return humDate.toLocaleDateString();
    } else {
      return day + ', ' + humDate.toLocaleDateString();
    }
  }
};