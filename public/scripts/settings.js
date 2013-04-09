(function () {
  var init, save;

  init = function() {
    var list, editions;
    
    if (period = store.get('period')) {
      $('select[name=period]').val(period);
      $('.subtitle').html($('.subtitle').html().replace(/\w+ly/, period));
    }

    list = $('.editions');
    if (editions = store.get('editions')) {
      list.html('');
      $.get('/partials/settings/edition', function(data) {
        var k, item, view;
        editions[''] = [];
        for (k in editions) {
          view = Mustache.render(data, {
            edition: k,
            subreddits: editions[k].join(' ')
          });
          
          item = $('<li>');
          item.html(view);
          item.addClass('edition');
          if (k === '') {
            item.addClass('empty');
          }
          list.append(item);
        }
      });
    }
    list.show();
  };

  save = function(e) {
    var data, period, titles, subreddits, editions, isEmpty, i, n;

    period = 'daily';
    titles = [];
    subreddits = [];
    editions = {}

    data = $(this).serializeArray();
    for (i = 0, n = data.length; i < n; i++) {
      switch (data[i].name) {
      case 'period':
        period = data[i].value;
        break;
      case 'titles[]':
        titles.push(data[i].value);
        break;
      case 'subreddits[]':
        // space separated list of subreddits
        subreddits.push(data[i].value.trim().split(/\s+/));
        break;
      }
    }
    // Zip 'titles' and 'subreddits' arrays in 'editions' object
    isEmpty = true;
    for (i = 0, n = titles.length; i < n; i++) {
      // Skip incomplete data
      if (titles[i].length && subreddits[i][0].length) {
        editions[titles[i]] = subreddits[i];
        isEmpty = false;
      }
    }
    if (isEmpty) {
      console.log('removing editions');
      // Submit form to get default values
      store.remove('editions');
      return true;
    }
    store.set('period', period);
    store.set('editions', editions);
    init();
    $('<p>')
      .addClass('message')
      .html('Settings saved')
      .appendTo($(this))
      .fadeIn()
      .delay(5000)
      .fadeOut(function() { $(this).remove(); });
    return false;
  };

  $(document).ready(function() {
    init();
    $('.message')
      .delay(5000)
      .fadeOut(function() { $(this).remove(); });
    $('form[data-role=settings]').submit(save);
  });

  $(document).on('click', '[data-role=settings] [data-action]', function(e) {
    var edition;

    e.preventDefault();
    switch ($(this).data('action')) {
      case 'add':
        edition = $('.edition.empty').clone();
        $('.editions').append(edition);
        edition.fadeIn(function() {
          edition.removeClass('empty');
        });
        break;
      case 'remove':
        $(this).parent().fadeOut(function() {
          $(this).remove();
        });
      break;
    }
  });

}).call(this);
