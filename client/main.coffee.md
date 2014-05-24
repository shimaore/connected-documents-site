    $ = require 'jquery'
    request = require 'superagent'

    seconds = 1000

We do not support offline yet.

    offline = false
    session = {}

    clear_session = ->
      session.user = null
      session.language = null
      session.display = null
      session._check = null

    clear_session()

    default_language: 'fr'

Application routing.

    Router = require './component/router'

    router = new Router

Create context for views.

    DB = require './db.coffee.md'
    views = require './views.coffee.md'

Session middleware :)

    get_session = (cb) ->

      now = new Date()
      if session._check? and now-session._check < 2*seconds
        cb()
        return

      request
      .get '/_app/session'
      .accept 'json'
      .end (res) ->
        session._check = new Date()
        if res.ok and res.body?.user?
          session.user = res.body.user
          session.roles = res.body.roles
          session.display = res.body.display
          cb()
          return

        clear_session()

        cb()
        return

    check_session = (cb) ->
      get_session ->
        if session.user?
          cb()
        else
          router.dispatch '/login'

Optimize loading of (normally not changing) server-side data

    the_public_store = null
    the_shared_store = null
    the_user_profile = null

    in_context = (cb) ->
      base = "#{window.location.protocol}//#{window.location.host}"
      the =
        router: router
        session: session
        shared_submit: (data,cb) ->
          request
          .post '/_app/shared_submit'
          .send data
          .timeout 1000
          .end (res) ->
            cb res.ok and res.body.ok
        private_submit: (data,cb) ->
          request
          .post '/_app/private_submit'
          .send data
          .timeout 1000
          .end (res) ->
            cb res.ok and res.body.ok
        user: {}

Append a view to the specific widget.

        view: (view_name) ->
          my_widget = $ '<div/>'

          my = {}
          my[k] = the[k] for own k of the

          my.widget = my_widget
          if views[view_name]?
            console.log "Loading view #{view_name}"
            views[view_name] my
          else
            console.log "Unknown view #{view_name}"
          my.widget

      set_language = (next) ->
        if session.language?
          the.user.language = session.language
          next the
          return

        request
        .get '/_app/language'
        .accept 'json'
        .end (res) ->
          if res.ok and res.body?[0]?
            session.language = res.body[0].code
          else
            session.language = default_language
          the.user.language = session.language
          next the

Avoid showing a login prompt if we're not logged in.

      if not offline and not session.user?

Load the `store` data from the public database.

        if the_public_store?
          the.store = the_public_store
          set_language cb
          return

        public_db = new DB "#{base}/public"
        public_db.pouch.get 'store'
        .then (doc) ->
          the.store = doc
          the_public_store = doc
          set_language cb
        .catch (error) ->
          console.log store:error
          set_language cb
        return

      get_the_shared_store = (cb) ->
        the.shareddb = new DB if offline then 'shared' else "#{base}/shared"

        if the_shared_store?
          the.store = the_shared_store
          cb()
          return

        the.shareddb.pouch.get 'store'
        .then (doc) ->
          the_shared_store = doc
          the.store = doc
          cb()
        .catch (error) ->
          console.log store:error
          cb()
          # FIXME Notify user? Retry?

      get_the_user_profile = (cb) ->
        the.userdb = new DB if offline then 'user' else "#{base}/user-#{session.user}"

        if the_user_profile?
          cb()
          return

        the.userdb.pouch.get 'profile'
        .then (doc) ->
          the_user_profile = doc
          the.user = doc
          session.language = doc.language
          setTimeout (-> the_user_profile = null), 10*seconds
          cb()
        .catch (error) ->
          console.log user_profile:error
          cb()

      get_the_shared_store -> get_the_user_profile -> set_language cb

Hash-tag based routing

    routes = ->

      @get '', ->
        check_session ->
          router.dispatch '/home'

      @get '/home', ->
        check_session ->

          # Home content:
          base = $ 'body'
          base.empty()

          in_context (the) ->
            base.append the.view 'top'
            base.append the.view 'menu'
            base.append the.view 'welcome_text'
            base.append the.view 'twitter_feeds'

            # Top content: questions (feedback)
            # List all current questions found in shared database, hide questions user already answered,
            base.append the.view 'questions'

            # List bookshelves:
            # - my new books (recently purchased, currently reading)
            # - wishlist(s)
            # - recently suggested books (esp. ones pending reviews)
            base.append the.view 'shelves'

      @get '/reading_club', ->
        check_session ->

          base = $ 'body'
          base.empty()

          in_context (the) ->
            base.append the.view 'top'
            base.append the.view 'menu'

            base.append the.view 'shared_content'

            # Content suggestion: books (by title, author), URLs
            base.append the.view 'content_submission'

      @get '/my_account', ->
        check_session ->
          base = $ 'body'
          base.empty()

          in_context (the) ->
            # Currently only profile options are: publish_profile, pseudonym, picture, publish_picture flag, description ('about me")
            # Note: the publish_picture flag is a private flag, when changed it adds or removes the picture attachment from the public profile.
            # Note: the public_profile flag is a private flag, when changed it adds or remove the profile from the shared db.
            base.append the.view 'top'
            base.append the.view 'menu'
            base.append the.view 'profile'

      @get '/content/:id', ->
        # Display content:

        # Description, picture (price, purchase button)

        # Comment section (sorted by upvoting count): user, date/time,

      @get '/user/:id', ->
        # Public user profile: pseudo, picture attachment, description if available.

Facebook callback bug workaround

      @get '_=_', ->
        router.dispatch '/login'

      @get '/login', ->
        # Login with email/password, facebook connect, or twitter connect

        get_session ->
          if session.user?
            router.dispatch '/home'
            return

          base = $ 'body'
          base.empty()
          base.append the.view 'top'
          base.append the.view 'welcome_text'
          base.append the.view 'register'
          base.append the.view 'login'
          base.append the.view 'login_or_register'
          return

      @get '/logout', ->
        clear_session()
        request
        .del '/_app/session'
        .accept 'json'
        .end (res) ->
          router.dispatch '/login'

    routes.apply router

Handle hashtag changes.
FIXME: Use a proper existing module (that deals properly with the right APIs) for this.

    old_location = null
    check_location = ->
      new_location = window.location.hash.substr 1
      if old_location isnt new_location
        console.log "Loading '#{new_location}'"
        old_location = new_location
        router.dispatch new_location

    # if window.location.watch?
    #   console.log "Using window.location.watch for check_location"
    #   window.location.watch 'hash', check_location
    # else
    if 'onhashchange' in window
      console.log "Using onhashchange for check_location"
      Event.bind window, 'hashchange', check_location
    else
      console.log "Using setInterval for check_location"
      setInterval check_location, 500

    check_location()
