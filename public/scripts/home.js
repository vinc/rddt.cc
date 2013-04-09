(function () {
  var init;

  String.prototype.chomply = function() {
    return this.slice(0, -2).replace('i', 'y');
  }

  init = function() {
    var list, editions, t;
    
    t = 'day';

    if (period = store.get('period')) {
      t = period.chomply();
      $('.subtitle').html($('.subtitle').html().replace(/\w+ly/, period));
    }

    list = $('.editions');
    if (editions = store.get('editions')) {
      list.html('');
      $.get('/partials/home/edition', function(data) {
        var i, n, k, r, view, item;
        
        item = $('li', data)[0].outerHTML;
        data = data.replace(item, '{{{items}}}');

        for (k in editions) {
          view = '';
          for (i = 0, n = editions[k].length; i < n; i++) {
            view += Mustache.render(item, {
              t: t,
              subreddits: editions[k][i]
            })
          }
          view = Mustache.render(data, {
            t: t,
            edition: k,
            subreddits: editions[k].join('+'),
            items: view
          });
          list.append(view);
        }
      });
    }
    list.show();
  };

  $(document).ready(function() {
    init();
  });

}).call(this);
