Facebook login

    $ = require 'jquery'

    loaded = false
    ready = false

    module.exports = (cb) ->
      $ ->
        if ready then return cb window.FB

        window.fbAsyncInit = ->
          window.FB.init
            appId      : the.store.facebook_app_id
            xfbml      : true
            version    : 'v2.0'
          ready = true
          cb window.FB

        if loaded then return
        $
        .getScript '//connect.facebook.net/en_US/sdk.js'
        .done ->
          loaded = true
        .fail ->
          console.log 'Failed to load Facebook SDK'
