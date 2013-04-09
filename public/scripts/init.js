(function () {
  var init;

  init = function() {
    var editions;

    if (period = store.get('period')) {
      $('.subtitle').html($('.subtitle').html().replace(/\w+ly/, period));
    }
  };

  $(document).ready(function() {
    init();
  });

}).call(this);
