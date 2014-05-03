    zappa = require 'zappajs'
    config = require '/usr/local/etc/proxy.json'
    crypto = require 'crypto'
    create_user_account = require './create_user_account'

    acceptLanguage = require 'accept-language'

    zappa config, ->

      acceptLanguage.codes config.languages

      @use 'logger'

      bodyParser = @express.bodyParser()

      express_store = do =>
        ExpressRedisStore = require('connect-redis') @express
        new ExpressRedisStore()

      @use 'cookieParser'
      @use session:
        store: express_store
        secret: config.session_secret

      @include './connect'
      @include './render'
      @include './private_submit'

Language
========

      @get '/_app/language', ->
        @json acceptLanguage.parse @req.get 'accept-language'

Session
=======

      @get '/_app/session', ->
        @json
          user: @session.user
          roles: @session.roles

Twitter connect
===============

We authenticate using Twitter; our internal username starts with "twitter:".

      @post '/_app/twitter-connect', [bodyParser], ->

        # pas besoin de mail de validation
        @twitter_connect (ok) =>
          if not ok then return @json error:'failed'

          username = "twitter:#{twitter_userid}"
          create_user_account {username,validated:true}, (error,uuid) =>
            @session.name = username
            @session.user = uuid
            @session.roles = ['user']
            @session.token = make_token @session

            @json
              ok: true
              uuid: uuid

Facebook connect
================

We authenticate using Facebook; our internal username starts with "facebook:".

      @post '/_app/facebook-connect', [bodyParser], ->

        username = @body.authResponse.userID

        # pas besoin de mail de validation
        @facebook_connect (ok) =>
          if not ok then return @json error:'failed'

          username = "facebook:#{twitter_userid}"
          create_user_account {username,validated:true}, (error,uuid) =>
            @session.name = username
            @session.user = uuid
            @session.roles = ['user']
            @session.token = make_token @session

            @json
              ok: true
              uuid: uuid

Local connect
=============

We authenticate using CouchDB; our internal username is an email adress (and identical to the CouchDB username).

      @post '/_app/local-connect', [bodyParser], ->

        @local_connect (ok) =>

          if not ok then return @json error:'failed'

          username = @body.username
          password = @body.password

          create_user_account {username,password}, (error,uuid) =>
            @session.name = username
            @session.user = uuid
            @session.roles = ['user']
            @session.token = make_token @session

            @json
              ok: true
              uuid: uuid

Register
========

This is only necessary for internal users.

      @post '/_app/register', [bodyParser], ->

        if @session.user?
          return @json already_connected: true

        username = @body.username
        password = @body.password

        create_user_account {username,password,validated:false}, (error,uuid) =>
          if error then return @json {error}

          @session.user = uuid

          @json
            ok: true
            uuid: uuid

Couch Proxy
===========

      @include './couch_proxy'

    make_token = (o) ->
      secret = config.couch_secret
      hmac = crypto.createHmac 'sha1', secret
      hmac.update o.name
      hmac.digest 'hex'
