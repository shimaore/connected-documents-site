    config = require '/usr/local/etc/proxy.json'
    request = require 'superagent'

    @include = ->

      @helper local_connect: (next) ->
        name = @body.username
        password = @body.password

        request
        .post [config.base_url,'_session'].join '/'
        .send {name,password}
        .accept 'json'
        .end (res) ->
          if not res.ok then return next false

          next res.body.ok
