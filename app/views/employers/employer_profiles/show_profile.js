$('#show_profile .col-md-10').html("<%= escape_javascript render("show_profile") %>")
$('.fade').addClass('in').addClass('active')
$('#inbox').removeClass('active').removeClass('in')
semantic_class();


$('div[name=employee_family_tabs] > ').children().each( function() { 
    $(this).change(function(){
      filter = $(this).val();
      $('#employees_' + filter).siblings().hide();
      $('#employees_' + filter).show();
      $.ajax({
        url: $('span[name=employee_families_url]').text() + '.js',
        type: "GET",
        data : { 'status': filter }
      });
    })
  })