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
    crypto = require 'crypto'

    texts =
      languages:
        fr: 'Français'
        en: 'English'
      language:
        fr: 'Langue'
        en: 'Language'
      name:
        fr: 'Nom'
        en: 'Name'
      description:
        fr: 'Bio'
        en: 'Bio'
      publish_profile:
        fr: 'Publier mon profil'
        en: 'Make my profile public'
      publish_description:
        fr: 'Publier ma bio'
        en: 'Make my bio public'
      publish_picture:
        fr: 'Publier ma photo'
        en: 'Make my picture public'
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
      url_link:
        fr: 'Lien URL'
        en: 'URL link'
      submit:
        fr: 'Proposer'
        en: 'Submit for review'
      title:
        fr: 'Titre'
        en: 'Title'
      author:
        fr: 'Auteur'
        en: 'Author'


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
            el = this
            window.twttr?.widgets.createTimeline the.store.twitter_widget_id, el, -> console.log 'timeline done'

Questions
=========

We only list questions a given user did not already submit.

      questions: (the) ->

        # FIXME keep_anonymous

        one_question = (el,q) =>
          # load the answer record
          if q.language isnt the.user.language
            return console.log "Skipping question #{q.question}, wrong language"
          the.userdb.find 'answer', q.question, (answer) ->
            answer ?= {}

            if answer.submitted
              console.log "Question was already submitted"
              return

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
                    if doc?
                      $(el).hide()
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

      profile: (the) ->
        the.widget.html render ->
          section class:'profile', ->
            form ->
              label ->
                span texts.name[the.user.language]
                input type:'text', 'x-bind':'value:/profile/name'
              label ->
                span texts.description[the.user.language]
                input type:'text', 'x-bind':'value:/profile/description'
              label ->
                span texts.publish_profile[the.user.language]
                input type:'checkbox', 'x-bind':'value:/profile/publish/profile'
              label ->
                span texts.publish_description[the.user.language]
                input type:'checkbox', 'x-bind':'value:/profile/publish/description'
              label ->
                span texts.publish_picture[the.user.language]
                input type:'checkbox', 'x-bind':'value:/profile/publish/picture'
              label ->
                img class:'picture', src:[the.userdb.name,'profile','picture'].join '/'
                input type:'file', class:'picture'
              label ->
                span texts.language[the.user.language]
                select 'x-bind':'value:/profile/language', ->
                  for o, name of texts.languages
                    option value:o, name
              div class:'notification'
              div class:'status'

        the.widget.find('input.picture').on 'change', ->
          selected_file = @files[0]
          return unless selected_file?

          if not selected_file.type.match /^image/
            alert 'Please select an image' # FIXME

          reader = new FileReader()

          reader.onload = ->
            attachment = reader.result
            the.userdb.pouch.get 'profile'
            .then (doc) ->
              the.userdb.pouch.putAttachment 'profile', 'picture', doc._rev, reader.result, selected_file.type
              .then (res) ->
                if res.ok
                  the.widget.find('img.picture').each ->
                    @src = [the.userdb.name,'profile','picture'].join('/')+"?rev=#{res.rev}"
              .catch (err) ->
                console.log err
                alert 'Failed, try again' # FIXME
            .catch (err) ->
              alert 'Failed, try again!' # FIXME

          reader.readAsArrayBuffer selected_file

        the.widget.find('form').each ->
          el = this
          status = $(el).find('.status')
          clear_status = ->
            status.removeClass('failed').removeClass('saved')
          the.userdb.find 'profile', null, (profile) ->
            profile ?= {}
            profile.language ?= the.session.language
            delete profile._attachments # prevents pflock from taking a long time to start

            bindings = pflock el, {profile}
            timer = null
            bindings.on 'changed', ->
              if timer? then clearTimeout timer
              update = ->
                status.addClass 'saving'
                the.userdb.update 'profile', null, bindings.data.profile, (doc,old_doc) ->
                  status.removeClass('saving').addClass if doc then 'saved' else 'failed'
                  setTimeout clear_status, 10000

                  bindings.toDocument {profile: doc ? old_doc}
                  timer = null
                  return
              timer = setTimeout update, 1000

Content submission
==================

      content_submission: (the) ->
        the.widget.html render ->
          section class:'content_submission', ->
            form ->
              label ->
                span texts.url_link[the.user.language]
                input type:'url', class:'url',  required:true
              label ->
                span texts.title[the.user.language]
                input type:'text', class:'title', required:true
              label ->
                span texts.author[the.user.language]
                input type:'text', class:'author', required:true
              input type:'submit', value:texts.submit[the.user.language]
              div class:'notification'
              div class:'status'
              img src:'/'

        the.widget.find('form').each ->
          el = this
          status = $(el).find('.status')
          $(el).find('.url').on 'focusout', ->
            url = $(@).val()
            request
            .post '/_app/website-image'
            .send {url}
            .accept 'json'
            .end (res) ->
              if res.ok
                $(el).find('img').attr 'src', "data:image/png;base64,#{res.body.content}"

          $(el).submit (e) ->
            e.preventDefault()
            status.addClass 'saving'
            h = crypto.createHash 'sha1'
            h.update $(el).find('input.url').val()
            uuid = h.digest 'hex'

            doc =
              type: 'content'
              _id: "content:#{uuid}"
              content: uuid
              submitted_by: the.session.user

              title: $(el).find('input.title').val()
              author: $(el).find('input.author').val()
              url: $(el).find('input.author').val()

            the.shared_submit doc, (ok) ->
              status.removeClass 'saving'
              status.addClass if ok then 'saved' else 'failed'

            return false

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
              div class:'notification'

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
              div class:'notification'

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

    {render,input,section,label,img,form,select,option,span,div,a,script,raw} = require 'teacup'
