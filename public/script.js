$(document).ready(function(){
  var options = {
    bgColor         : '#fff',
    duration        : 800,
    opacity     : 0.7,
    classOveride    : false
  }

  var block;

  $("#check-submit").click(function(){
    $.ajax({
      url: 'movie',
      cache: false,
      type:'POST',
      data: { movie: $('#movie').val()},
      error: function(xhr) {
        alert('Ajax request 發生錯誤');
      },
      success: function(response) {
        window.location.href = "http://localhost:9292" + response;
      }
    });
  });
 
  $(document).ajaxStart(function(){
    block = new ajaxLoader(this, options);
  });

  $(document).ajaxStop(function(){
    block.remove();
  });
});