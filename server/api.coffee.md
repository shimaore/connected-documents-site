    zappa = require 'zappajs'
    config = require '/usr/local/etc/proxy.json'
    crypto = require 'crypto'
    passport = require 'passport'
    create_user_account = require './create_user_account'

    acceptLanguage = require 'accept-language'

    qs = require 'querystring'

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
      @include './shared_submit'

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

Passport Authentication Callback URL Handler
============================================

      passport_callback = (strategy) ->
        return ->
          handler = (error,username,info) =>
            console.dir {error,username,info}

            return_url = "#{config.public_url}/public/_design/site/index.html"

            if error
              return @redirect "#{return_url}?#{qs.stringify {error}}"

            if not username
              return @redirect "#{return_url}?#{qs.stringify error:'failed'}"

            create_user_account {username,validated:true}, (error,uuid) =>
              if error
                console.dir error
                return @redirect "#{return_url}?#{qs.stringify {error}}"

              @session.name = username
              @session.user = uuid
              @session.roles = ['user']
              @session.token = make_token @session

              console.dir @session

              @redirect "#{return_url}?#{qs.stringify {uuid,ok:true}}"

          (passport.authenticate strategy, handler)(@req,@res,@next)

Twitter connect
===============

We authenticate using Twitter; our internal username starts with "twitter:".

      TwitterStrategy = (require 'passport-twitter').Strategy

      passport.use new TwitterStrategy
        consumerKey: config.twitter_consumer_key
        consumerSecret: config.twitter_consumer_secret
        callbackURL: "#{config.public_url}/_app/twitter-connect/callback"
        (accessToken, refreshToken, profile, done) ->
          done null, "twitter-#{profile.id}"

      @get '/_app/twitter-connect', passport.authenticate 'twitter'
      @get '/_app/twitter-connect/callback', passport_callback 'twitter'

Facebook connect
================

We authenticate using Facebook; our internal username starts with "facebook:".

      FacebookStrategy = (require 'passport-facebook').Strategy

      passport.use new FacebookStrategy
        clientID: config.facebook_app_id
        clientSecret: config.facebook_app_secret
        callbackURL: "#{config.public_url}/_app/facebook-connect/callback"
        (accessToken, refreshToken, profile, done) ->
          done null, "facebook-#{profile.id}"

      @get '/_app/facebook-connect', passport.authenticate 'facebook' # , scope:'email'
      @get '/_app/facebook-connect/callback', passport_callback 'facebook'

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
