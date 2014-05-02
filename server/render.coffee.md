Website image
=============

Start the image rendering service.

    renderer = require './render/start'

Handle requests for images by proxying them.

    request = require 'superagent'

    @include = ->

      @post '/_app/website-image', [bodyParser], ->
        url = @body.url
        request
        .post 'http://127.0.0.1:8083'
        .send {url}
        .accept 'json'
        .end (res) =>
          if res.ok
            buf = new Buffer res.body.content, 'base64'
            @res.set 'Content-Type', 'image/png'
            @send buf
          else
            @res.status 500
            @send ''
