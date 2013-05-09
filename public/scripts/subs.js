(function () {
  var init;

  init = function() {
    var period, limit;

    if (period = store.get('period')) {
      $('.subtitle').html($('.subtitle').html().replace(/\w+ly/, period));
    }

    limit = store.get('limit') || 20;
    $('.news article').each(function(i) {
      if (i >= limit) {
        $(this).hide();
      }
    });
  };

  $(document).ready(function() {
    init();
  });

}).call(this);
