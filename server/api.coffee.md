    zappa = require 'zappajs'
    config = require '/usr/local/etc/proxy.json'
    create_user_account = require './create_user_account'


    zappa config, ->


      @use 'logger'

      # TODO
      # Note: it's probably oauth. Let CouchDB auth for us.
      # (Use the "behind couchdb auth" scheme. -- except for initial registration everything must be authed by CouchDB, and we sit behind it so we can access its session cookie. Write middleware to validate the session cookie with CouchDB.)
      @post '/_app/twitter-connect', ->
        # pas besoin de mail de validation
        twitter_connect (ok) ->
          if not ok then return @json error:'failed'

          create_user_account {username,password,validated:true}, (error,uuid) ->
            @session.user = uuid

            @json
              ok: true
              uuid: uuid

      @post '/_app/facebook-connect', ->

        username = @body.authResponse.userID

        # pas besoin de mail de validation
        facebook_connect (ok) ->
          if not ok then return @json error:'failed'

          create_user_account {username,password,validated:true}, (error,uuid) ->
            @session.username = username

            @json
              ok: true
              uuid: uuid

      # FIXME this is probably part of hoodiehq already?
      @post '/_app/register', ->

        if @session.user
          return @json already_connected: true

        username = @body.username
        password = @body.password

        create_user_account {username,password}, (error,uuid) ->
          if error then return @json {error}

          @session.user = uuid

          @json
            ok: true
            uuid: uuid

      @include './couch_proxy'
