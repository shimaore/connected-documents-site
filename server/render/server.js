var webserver = require('webserver');
var webpage = require('webpage');

var server = webserver.create();
var port = 8083;
server.listen(port,function(request,response){
  body = JSON.parse(request.postRaw);
  var url = body.url;
  console.log("New request for "+url);
  var page = webpage.create();
  page
  .open(url)
  .then(function(){
    page.viewportSize = { width:800, height:600 };
    setTimeout( function(){
      var content = page.renderBase64({format:'PNG',onlyViewport:true});
      response.setHeader('Content-Type','application/json');
      response.write(JSON.stringify({content:content}));
      response.close();
      console.log("Request completed for "+url);
    },3000);
  });
});
console.log("Server started on port "+port);
