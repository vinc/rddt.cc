(function () {
  var init;

  String.prototype.chomply = function() {
    return this.slice(0, -2).replace('i', 'y');
  }

  init = function() {
    var editions;

    if (period = store.get('period')) {
      $('.subtitle').html($('.subtitle').html().replace('daily', period));
    }
  };

  $(document).ready(function() {
    init();
  });

}).call(this);
