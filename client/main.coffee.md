    $ = require 'dom'
    request = require 'superagent'

We do not support offline yet.

    offline = false
    user_id = null

Create context for views.

    DB = require './db'
    views = require './views'

    in_context = (cb) ->
      base = "#{window.location.protocol}//#{window.location.host}"
      console.log "Using base = #{base}"
      the =
        shareddb: new DB if offline then 'shared' else "#{base}/shared"
        shared_submit: (data,cb) ->
          request
          .post '/_app/shared_submit'
          .send data
          .timeout 1000
          .end (res) ->
            cb res.ok
        private_submit: (data,cb) ->
          request
          .post '/_app/private_submit'
          .send data
          .timeout 1000
          .end (res) ->
            cb res.ok

      the.shareddb.pouch.get 'store'
      .then (doc) ->
        the.store = doc
        the.user = {}

        if not offline and not user_id?
          cb the

        the.userdb = new DB if offline then 'user' else "#{base}/user-#{user_id}"
        the.userdb.pouch.get 'profile'
        .then (doc) ->
          the.user = doc
          cb the
        .catch (error) ->
          console.log user_profile:error

      .catch (error) ->
        console.log store:error
        # FIXME Notify user? Retry?

Append a view to the specific (component-dom) widget.

    append_view = (base_widget,view_name) ->
      in_context (the) ->
        the.widget = $ '<div/>'
        base_widget.append the.widget

        console.log "Loading view #{view_name}"
        views[view_name]? the

Application routing.

    Router = require 'router' # component 'component-router'

    router = new Router

Hash-tag based routing

    routes = ->

      @get '', ->
        if user_id?
          router.dispatch '/home'
        else
          router.dispatch '/login'

      @get '/home', ->
        # Home content:
        base = $ 'body'

        # Top menu: profile, logout
        append_view base, 'welcome_text'
        append_view base, 'twitter_feeds'

        # Top content: questions (feedback)
        # List all current questions found in shared database, hide questions user already answered,
        append_view base, 'questions'

        # Content suggestion: books (by title, author), URLs

        # List bookshelves:
        # - my new books (recently purchased, currently reading)
        # - wishlist(s)
        # - recently suggested books (esp. ones pending reviews)

        # 

      @get '/profile', ->
        # Currently only profile options are: publish_profile, pseudonym, picture, publish_picture flag, description ('about me")
        # Note: the publish_picture flag is a private flag, when changed it adds or removes the picture attachment from the public profile.
        # Note: the public_profile flag is a private flag, when changed it adds or remove the profile from the shared db.

      @get '/content/:id', ->
        # Display content:

        # Description, picture (price, purchase button)

        # Comment section (sorted by upvoting count): user, date/time,

      @get '/user/:id', ->
        # Public user profile: pseudo, picture attachment, description if available.

      @get '/login', ->
        # Login with email/password, facebook connect, or twitter connect

        ## For now use CouchDB session; later we'll use our own authenticating proxy.
        request
        .get '/_session'
        .accept 'json'
        .end (res) ->
          if not res.ok
            return console.log "Session failed" # FIXME
          if res.body.userCtx.name?
            user_name = res.body.userCtx.name

          if not user_name
            return console.log "No username" # FIXME
          else
            console.log "Username = #{user_name}"

          request
          .get "/_users/org.couchdb.user:#{user_name}"
          .accept 'json'
          .end (res) ->
            if not res.ok
              return console.log "No user info" # FIXME
            # FIXME check for `created`
            # FIXME check for `validated`
            if res.body.user_uuid?
              user_id = res.body.user_uuid
              router.dispatch '/home'

        # Registration


    routes.apply router

Handle hashtag changes.

    old_location = null
    check_location = ->
      new_location = window.location.hash.substr 1
      if old_location isnt new_location
        console.log "Loading '#{new_location}'"
        old_location = new_location
        router.dispatch new_location

    if window.location.watch?
      window.location.watch 'hash', check_location
    else if 'onhashchange' in window
      Event.bind window, 'hashchange', check_location
    else
      setInterval check_location, 500

    check_location()
