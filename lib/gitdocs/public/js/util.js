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