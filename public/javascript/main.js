//nav
$(document).ready(function() {
  //auto active
  $('li a').each(function(){
    if(this.href == window.location.href) {
      $(this).parent().addClass('active');
    }
  })
  //room for the nav
  $(document).on('click', function(event){
    if(event.target.href) {
      setTimeout(function(){
        $('body').scrollTop($('body').scrollTop() - 50);
      });
    }
  });
  $('#toc').toc({
    container: '#main',
    onHighlight: function(el) {
      $('#toc').find('li').removeClass('active');
      $(el).addClass('active');
    }
  });
  $('#toc > ul').addClass('nav nav-pills nav-stacked');
  if($('#toc').children.length == 0) {
    $('#leftnav').hide();
  } else {
    $('#main').addClass('navpad');
  }
  $('table').addClass('table table-bordered table-striped');
  $('pre code').each(function(i, e) {console.log(e);hljs.highlightBlock(e)});
});
