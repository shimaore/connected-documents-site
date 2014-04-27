    $ = require 'dom'

We do not support offline yet.

    offline = false
    user_id = null

Create context for views.

    DB = require './db'
    views = require './views'

    in_context = (cb) ->
      the =
        shareddb: new DB if offline? then 'shared' else '/shared'
        private_submit: (data,cb) ->
          request.post '/_app/private_submit', data, (err,res) ->
            if err? or not res.ok
              cb false
            else
              cb true

      the.shareddb.get 'store'
      .then (doc) ->
        the.store = doc

        if not user_id?
          cb the

        the.userdb = new DB if offline? then 'user' else "/#{user_id}"
        the.userdb.get 'profile'
        .then (doc) ->
          the.user = doc

          cb the
      .catch (err) ->
        console.log err
        # FIXME Notify user? Retry?

Append a view to the specific (component-dom) widget.

    append_view = (base_widget,view_name) ->
      in_context (the) ->
        the.widget = $ '<div/>'
        base_widget.append the.widget

        views[view_name] the

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
