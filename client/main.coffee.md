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

    check_session = (cb) ->

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

        public_db = new DB "#{base}/public"
        public_db.pouch.get 'store'
        .then (doc) ->
          the.store = doc
          set_language cb
        .catch (error) ->
          console.log store:error
          set_language cb
        return

      the.shareddb = new DB if offline then 'shared' else "#{base}/shared"

      the.shareddb.pouch.get 'store'
      .then (doc) ->
        the.store = doc

        the.userdb = new DB if offline then 'user' else "#{base}/user-#{session.user}"
        the.userdb.pouch.get 'profile'
        .then (doc) ->
          the.user = doc
          session.language = doc.language
          set_language cb
        .catch (error) ->
          console.log user_profile:error
          set_language cb

      .catch (error) ->
        console.log store:error
        set_language cb
        # FIXME Notify user? Retry?

Append a view to the specific (component-dom) widget.

    append_view = (base_widget,view_name) ->
      the_widget = $ '<div/>'
      base_widget.append the_widget

      in_context (the) ->
        the.widget = the_widget
        if views[view_name]?
          console.log "Loading view #{view_name}"
          views[view_name] the
        else
          console.log "Unknown view #{view_name}"

Hash-tag based routing

    routes = ->

      @get '', ->
        check_session ->
          if session.user?
            router.dispatch '/home'
          else
            router.dispatch '/login'

      @get '/home', ->
        check_session ->
          if not session.user?
            router.dispatch '/login'
            return

          # Home content:
          base = $ 'body'
          base.empty()

          # Top menu: profile, logout
          append_view base, 'top'
          append_view base, 'menu'
          # append_view base, 'logout'
          append_view base, 'welcome_text'
          append_view base, 'twitter_feeds'

          # Top content: questions (feedback)
          # List all current questions found in shared database, hide questions user already answered,
          append_view base, 'questions'

          # List bookshelves:
          # - my new books (recently purchased, currently reading)
          # - wishlist(s)
          # - recently suggested books (esp. ones pending reviews)
          append_view base, 'shelves'

          append_view base, 'shared_content'

          # Content suggestion: books (by title, author), URLs
          append_view base, 'content_submission'

      @get '/profile', ->
        check_session ->
          base = $ 'body'
          base.empty()

          # Currently only profile options are: publish_profile, pseudonym, picture, publish_picture flag, description ('about me")
          # Note: the publish_picture flag is a private flag, when changed it adds or removes the picture attachment from the public profile.
          # Note: the public_profile flag is a private flag, when changed it adds or remove the profile from the shared db.
          append_view base, 'top'
          append_view base, 'menu'
          append_view base, 'profile'
          # append_view base, 'logout'

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

        check_session ->
          if session.user?
            router.dispatch '/home'
            return

          base = $ 'body'
          base.empty()
          append_view base, 'top'
          append_view base, 'welcome_text'
          append_view base, 'register'
          append_view base, 'login'
          append_view base, 'login_or_register'
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
