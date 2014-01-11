// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
// require jquery
// require jquery_ujs
//= require foundation
//= require chosen.jquery
// require turbolinks
//= require_tree .

$(function(){

  $(document).foundation();

  $('#contact-modal').on('submit', 'form', function(e) {

    $.ajax({
      type: "POST",
      url: e.target.getAttribute('action'),
      data: $(e.target).serialize(),
      success: function() {
        e.target.reset();
        $('#contact-modal').foundation('reveal', 'close');
        alertBox('Message sent successfully!', 'success');
      },
      error: function() {
        alertBox('Unexpected error.', 'alert');
      }
    });

    return false;

  });

  $('.image-as-radio').on('click', '.picto', function(e) {

    var elt = $(e.target);
    var radio = elt.siblings(':radio');

    previously_selected = elt.hasClass('selected');
    should_be_selected = !previously_selected;

    if (should_be_selected && !radio.is(':checked')) {

      radio[0].checked = true;

      elt.parents('.image-as-radio').find('.picto').removeClass('selected');
      elt.addClass('selected');
    }

  });

  var alert_children = $('#alerts').children();
  setTimeout(function() { alert_children.slideUp(); }, 5000);

});

function alertBox(content, klass) {

  var alert_contents = $.parseHTML('<div data-alert style="display:none;" class="alert-box ' + klass + '">' + content + '<a href="#" class="close">&times;</a></div>');

  $('#alerts').append(alert_contents);
  $(alert_contents).slideDown();
  setTimeout(function() {
    $(alert_contents).slideUp();
  }, 5000);

}

