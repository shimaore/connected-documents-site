    $ = require 'jquery'
    request = require 'superagent'

We do not support offline yet.

    offline = false
    session =
      user: null
      language: null

    default_language: 'fr'

Application routing.

    Router = require './component/router'

    router = new Router

Create context for views.

    DB = require './db.coffee.md'
    views = require './views.coffee.md'

    in_context = (cb) ->
      base = "#{window.location.protocol}//#{window.location.host}"
      console.log "Using base = #{base}"
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
        console.log 'Avoiding database queries'
        set_language cb
        return

      console.log "Loading for user #{session.user}"

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
      in_context (the) ->
        the.widget = $ '<div/>'
        base_widget.append the.widget

        if views[view_name]?
          console.log "Loading view #{view_name}"
          views[view_name] the
        else
          console.log "Unknown view #{view_name}"

Hash-tag based routing

    routes = ->

      @get '', ->
        if session.user?
          router.dispatch '/home'
        else
          router.dispatch '/login'

      @get '/home', ->
        # Home content:
        base = $ 'body'
        base.empty()

        # Top menu: profile, logout
        append_view base, 'profile'
        append_view base, 'welcome_text'
        append_view base, 'twitter_feeds'

        # Top content: questions (feedback)
        # List all current questions found in shared database, hide questions user already answered,
        append_view base, 'questions'

        # Content suggestion: books (by title, author), URLs
        append_view base, 'content_submission'

        # List bookshelves:
        # - my new books (recently purchased, currently reading)
        # - wishlist(s)
        # - recently suggested books (esp. ones pending reviews)
        append_view base, 'shelves'

        # 
        append_view base, 'shared_content'

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

        request
        .get '/_app/session'
        .accept 'json'
        .end (res) ->
          if res.ok and res.body?.user?
            session.user = res.body.user
            session.roles = res.body.roles
            router.dispatch '/home'
            return

          base = $ 'body'
          base.empty()
          append_view base, 'login'
          append_view base, 'register'
          return

      @get '/logout', ->
        session.user = null
        router.dispatch ''

      @get '/test', ->
        base = $ 'body'
        base.empty()
        request
        .post '/_app/website-image'
        .send url:'http://shimaore.net'
        ## .accept 'image/png'
        .accept 'json'
        .end (res) ->
          ###
          blob = new Blob res.text, type:'image/png'
          src = window.URL.createObjectURL blob
          ###
          src = "data:image/png;base64,#{res.body.content}"
          $( '<img/>', src:src ).appendTo base
          window.URL.revokeObjectURL src

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
