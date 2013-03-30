(function () {

    $(document).on('click', '[data-action]', function(e) {
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
