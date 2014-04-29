    zappa = require 'zappajs'
    config = require '/usr/local/etc/proxy.json'
    create_user_account = require './create_user_account'

    zappa config, ->

      @use 'logger'

Twitter connect
===============

We authenticate using Twitter; our internal username starts with "twitter:".

      @post '/_app/twitter-connect', ->

        # pas besoin de mail de validation
        twitter_connect (ok) ->
          if not ok then return @json error:'failed'

          username = "twitter:#{twitter_userid}"
          create_user_account {username,validated:true}, (error,uuid) ->
            @session.user = uuid
            @session.roles = ['user']
            @session.token = make_token @session

            @json
              ok: true
              uuid: uuid

Facebook connect
================

We authenticate using Facebook; our internal username starts with "facebook:".

      @post '/_app/facebook-connect', ->

        username = @body.authResponse.userID

        # pas besoin de mail de validation
        facebook_connect (ok) ->
          if not ok then return @json error:'failed'

          username = "facebook:#{twitter_userid}"
          create_user_account {username,validated:true}, (error,uuid) ->
            @session.user = username
            @session.roles = ['user']
            @session.token = make_token @session

            @json
              ok: true
              uuid: uuid

Local connect
=============

We authenticate using CouchDB; our internal username is an email adress (and identical to the CouchDB username).

      @post '/_app/local-connect', ->

        local_connect (ok) ->

          if not ok then return @json error:'failed'

          @session.user = username
          @session.roles = ['user']
          @session.token = make_token @session

          @json
            ok: true
            uuid: uuid

Register
========

This is only necessary for internal users.

      @post '/_app/register', ->

        if @session.user
          return @json already_connected: true

        username = @body.username
        password = @body.password

        create_user_account {username,password,validated:false}, (error,uuid) ->
          if error then return @json {error}

          @session.user = uuid

          @json
            ok: true
            uuid: uuid

Couch Proxy
===========

      @include './couch_proxy'
