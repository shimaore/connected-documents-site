Website image
=============

Start the image rendering service.

    renderer = require './render/start'

    do renderer

Handle requests for images by proxying them.

    request = require 'superagent'

    @include = ->

      bodyParser = @express.bodyParser()

      @post '/_app/website-image', [bodyParser], ->
        url = @body.url
        request
        .post 'http://127.0.0.1:8083'
        .send {url}
        .accept 'json'
        .end (res) =>
          if res.ok
            @json res.body
            ###
            # The following works just fine, but is difficult to use client-side.
            buf = new Buffer res.body.content, 'base64'
            @res.set 'Content-Type', 'image/png'
            @send buf
            ###
          else
            @res.status 500
            @send ''
