These functions are called with:
`widget` -- a newly created component-dom `<div>` or other, empty at startup.
`userdb` -- a db instance to the current user's db
`shareddb` -- a db instance (read-only in most cases)
`private_submit` -- save a document into the private database, callback receives true if success
`store` -- the `store` record in `shareddb` when online, `userdb` when offline
`user` -- the `profile` record for the user (found in their `userdb`)

    pflock = require 'pflock-browserify'
    $ = require 'jquery'
    request = require 'superagent'

    texts =
      logout:
        fr: 'Déconnexion'
        en: 'Log out'
      submit_response:
        fr: "J'ai répondu"
        en: "I answered"
      email:
        fr: 'Address de mail'
        en: 'Email address'
      password:
        fr: 'Mot de passe'
        en: 'Password'
      login_submit:
        fr: 'Login'
        en: 'Login'
      login_error: # System / network error
        fr: "Veuillez ré-essayer"
        en: "Please try again"
      login_failed: # User error
        fr: "Email ou mot de passe incorrect"
        en: "Invalid email or password"
      register_submit:
        fr: 'Register'
        en: 'Register'
      register_error: # System / network error
        fr: "Veuillez ré-essayer"
        en: "Please try again"
      register_failed: # User error
        fr: "Une erreur est survenue, veuillez ré-essayer"
        en: "Invalid email or password"


    module.exports = widgets =

Texte administrable (welcome text)
==================================

      welcome_text: (the) ->
        if the.store.welcome_text?
          the.widget.text the.store.welcome_text[the.user.language]

      logout: (the) ->
        the.widget.text the.store.logout[the.user.language]

Twitter feeds
=============

      twitter_feeds: (the) ->
        if the.store.twitter_username? and the.store.twitter_widget_id?
          the.widget.each ->
            window.twttr?.widgets.createTimeline the.store.twitter_widget_id, this, -> console.log 'timeline done'

Questions
=========

We only list questions a given user did not already submit.

      questions: (the) ->

        # FIXME keep_anonymous

        one_question = (el,q) =>
          # load the answer record
          console.log "Loading answer record for #{q.question}"
          if q.language isnt the.user.language
            return console.log "Skipping question, wrong language"
          the.userdb.find 'answer', q.question, (answer) ->
            console.log {answer}
            answer ?= {}

            if answer.submitted
              return console.log "Question was already submitted"

            input_html =
              switch q.answer_type
                when 'boolean'
                  render -> input type:'checkbox', 'x-bind':'value:/answer/content'
                when 'string'
                  render -> input 'x-bind':'value:/answer/content'
                else
                  render -> select 'x-bind': 'value:/answer/content', ->
                    for o in q.answer_type
                      option value:o, o

            el.html render ->
              div class:'question', ->
                span q.text
                raw input_html
              div class:'submitted', ->
                span texts.submit_response[the.user.language]
                input type:'checkbox', 'x-bind':'value:/answer/submitted'

            el.each ->
              bindings = pflock this, {answer}
              bindings.on 'changed', ->
                data = bindings.data.answer
                the.private_submit data, (ok) ->
                  data.submitted = ok
                  the.userdb.update 'answer', q.question, data, (doc,old_doc) ->
                    bindings.toDocument {answer: doc ? old_doc}
                    return

        the.shareddb.all 'question', (questions) ->
          for q in questions
            el = $ '<div/>'
            the.widget.append el
            one_question el, q

Shelves
=======

Content
=======

Content comments
================

User Profile
============

Content submission
==================

Login widget
============

Shows the login prompt and options to login using Facebook and Twitter.

      login: (the) ->
        the.widget.html render ->
          section class:'login', ->
            form ->
              label ->
                span texts.email[the.user.language]
                input type:'email', class:'username'
              label ->
                span texts.password[the.user.language]
                input type:'password', class:'password'
              input type:'submit', value:texts.login_submit[the.user.language]
              div class:'.notification'

Form submission for internal users.

        the.widget.on 'submit', 'form', (e) ->
          console.log 'submit login form'
          e.preventDefault()
          auth =
            username: the.widget.find('.username').val() # val() for jQuery, value() for component/dom
            password: the.widget.find('.password').val()
          request
          .post '/_app/local-connect'
          .accept 'json'
          .send auth
          .end (res) ->
            if not res.ok
              the.widget.find('.notification').text texts.login_error[the.user.language]
              return

            if not res.body.ok
              the.widget.find('.notification').text texts.login_failed[the.user.language]
              return

            the.session.user = res.body.uuid
            the.router.dispatch ''

          return false

        console.log "View login is ready"

Register widget
===============

      register: (the) ->
        the.widget.html render ->
          section class:'register', ->
            form ->
              label ->
                span texts.email[the.user.language]
                input type:'email', class:'username'
              label ->
                span texts.password[the.user.language]
                input type:'password', class:'password'
              input type:'submit', value:texts.register_submit[the.user.language]
              div class:'.notification'

Form submission for internal users.

        the.widget.on 'submit', 'form', (e) ->
          console.log 'submit register form'
          e.preventDefault()
          auth =
            username: the.widget.find('.username').val()
            password: the.widget.find('.password').val()
          request
          .post '/_app/register'
          .accept 'json'
          .send auth
          .end (res) ->
            if not res.ok
              the.widget.find('.notification').text texts.register_error[the.user.language]
              return

            if not res.body.ok
              the.widget.find('.notification').text texts.register_failed[the.user.language]
              return

            the.session.user = res.body.uuid
            the.router.dispatch ''

          return false

        console.log "View register is ready"

Toolbox
=======

    {render,input,section,label,form,select,option,span,div,a,script,raw} = require 'teacup'
