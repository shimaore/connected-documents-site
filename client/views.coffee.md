These functions are called with:
`widget` -- a newly created jquery `<div>` or other, empty at startup.
`userdb` -- a DB for the current user's db
`shareddb` -- a DB for the shared db (read-only in most cases)
`private_submit` -- save a document into the private database, callback receives true if success
`shared_submit` -- save a document into the shared database, callback receives true if success
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
      login_with:
        fr: 'Se connecter avec '
        en: 'Login with '
      login_error: # System / network error
        fr: "Veuillez ré-essayer"
        en: "Please try again"
      login_failed: # User error
        fr: "Email ou mot de passe incorrect"
        en: "Invalid email or password"
      register_submit:
        fr: 'Créer un compte'
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
      shared_content:
        fr: 'Contenu partagé'
        en: 'Shared content'


    module.exports = widgets =

Texte administrable (welcome text)
==================================

      welcome_text: (the) ->
        if the.store.welcome_text?
          the.widget.html render ->
            div '.color-grey.welcome', the.store.welcome_text[the.user.language]

      logout: (the) ->
        the.widget.html render ->
          a href:'#/logout', texts.logout[the.user.language]

      top: (the) ->
        the.widget.html render ->
          img '.logo', src:"logo-#{the.user.language}.png"

Twitter feeds
=============

      twitter_feeds: (the) ->
        if the.store.twitter_username? and the.store.twitter_widget_id?
          the.widget.each ->
            el = this
            window.twttr?.widgets.createTimeline the.store.twitter_widget_id, el, -> console.log 'timeline done'

"Like" Facebook button
======================

Questions
=========

We only list questions a given user did not already submit.

      questions: (the) ->

        the.shareddb.all 'question', (questions) ->
          for q in questions when q.language is the.user.language
            el = $ render ->
              div '.form-question'
            the.widget.append el
            widgets.one_question the, el, q

One question
============

      one_question: (the,el,q) ->

        # FIXME keep_anonymous

        # load the answer record
        the.userdb.find 'answer', q.question, (answer) ->
          answer ?= {}

          if answer.submitted
            console.log "Question was already submitted"
            return

          input_html =
            switch q.answer_type
              when 'boolean'
                render ->
                  input type:'checkbox', 'x-bind':'value:/answer/content'
                  label q.text
              when 'string'
                render ->
                  label q.text
                  input '.form-control',
                    type:'text', 'x-bind':'value:/answer/content'
              else
                render ->
                  label q.text
                  select 'x-bind': 'value:/answer/content', ->
                    for o in q.answer_type
                      option value:o, o

          el.html render ->
            div '.question.form-group', ->
              raw input_html
            div '.submitted.form-group', ->
              input type:'checkbox', 'x-bind':'value:/answer/submitted'
              label texts.submit_response[the.user.language]

          el.each ->
            bindings = pflock this, {answer}
            bindings.on 'changed', ->
              data = bindings.data.answer
              return unless data.submitted
              the.private_submit data, (ok) ->
                data.submitted = ok
                the.userdb.update 'answer', q.question, data, (doc,old_doc) ->
                  bindings.toDocument {answer: doc ? old_doc}
                  if doc?.submitted
                    $(el).hide()
                  return

My Shelves
==========

      shelves: (the) ->
        view =
          map: (doc) ->
            if doc.type is 'content' and doc.categories?
              for category in doc.categories
                emit category, null
        the.userdb.add_view 'shelves/by_category', view, ->
          the.userdb.pouch
            .query 'shelves/by_category', include_docs: true, stale: 'update_after'
            .then (res) ->

TODO: List by categories!!

              current_category = null
              current_category_widget = null

              for row in res.rows
                if current_category isnt row.key
                  current_category = row.key
                  current_category_widget = $ render -> div '.category'
                  current_category_widget.append $ render ->
                    div '.category-header', current_category
                  the.widget.append current_category
                el = $ render ->
                  div '.content-items'
                current_category.append el
                widgets.content_preview the, el, the.userdb, row.doc

Shared Content
==============

This is content that can be freely added to my own shelves.

      shared_content: (the) ->
        the.shareddb
          .all 'content', (docs) ->
            the.widget.append $ render ->
              div '.category-header', texts.shared_content[the.user.language]
            for doc in docs
              el = $ render ->
                div '.content-items'
              the.widget.append el
              widgets.content_preview the, el, the.shareddb, doc

Content Preview
===============

      content_preview: (the,el,db,doc) ->
        el.html render ->
          div '.content-preview', ->
            a href:doc.url, ->
              if doc._attachments?.thumbnail?
                img '.thumbnail', src:[db.name,doc._id,'thumbnail'].join '/'
              else
                img '.thumbnail', src:'coeur.png'
            div '.title', ->
              i '.fa.fa-book'
              span doc.title
            div '.author', ->
              i '.fa.fa-pencil'
              span doc.author


Content comments
================

User Profile
============

      profile: (the) ->
        the.widget.html render ->
          section '.profile', ->
            form '.form-profile', role:'form', ->
              div '.form-group', ->
                label texts.name[the.user.language]
                input '.form-control',
                  type:'text', 'x-bind':'value:/profile/name'
              div '.form-group', ->
                label texts.description[the.user.language]
                textarea '.form-control', 'x-bind':'/profile/description'
              div '.checkbox', ->
                input type:'checkbox', 'x-bind':'value:/profile/publish/profile'
                label texts.publish_profile[the.user.language]
              div '.checkbox', ->
                input type:'checkbox', 'x-bind':'value:/profile/publish/description'
                label texts.publish_description[the.user.language]
              div '.checkbox', ->
                input type:'checkbox', 'x-bind':'value:/profile/publish/picture'
                label texts.publish_picture[the.user.language]
              div '.form-group', ->
                if the.user._attachments?.picture?
                  img '.picture', src:[the.userdb.name,'profile','picture'].join '/'
                else
                  img '.picture', src:'coeur.png'
                input '.picture', type:'file'
              div '.form-group', ->
                label texts.language[the.user.language]
                select '.form-control', 'x-bind':'value:/profile/language', ->
                  for o, name of texts.languages
                    option value:o, name
              div '.notification'
              div '.status'

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
          section '.content_submission', ->
            form '.form-submission', ->
              div '.form-group', ->
                label texts.url_link[the.user.language]
                input '.url.form-control',
                  type:'url', required:true
                img '.thumbnail', src:'coeur.png'
              div '.form-group', ->
                label texts.title[the.user.language]
                input '.title.form-control',
                  type:'text', required:true
              div '.form-group', ->
                label texts.author[the.user.language]
                input '.author.form-control',
                  type:'text', required:true
              input '.btn.btn-default',
                type:'submit', value:texts.submit[the.user.language]
              div '.notification'
              div '.status'

        the.widget.find('form').each ->
          el = this
          status = $(el).find('.status')
          thumbnail = null
          $(el).find('.url').on 'focusout', ->
            url = $(@).val()
            request
            .post '/_app/website-image'
            .send {url}
            .accept 'json'
            .end (res) ->
              if res.ok
                $(el).find('img.thumbnail').attr 'src', "data:image/png;base64,#{res.body.content}"
                thumbnail = res.body.content

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
              url: $(el).find('input.url').val()

            if thumbnail?

              doc._attachments =
                thumbnail:
                  content_type: 'image/png'
                  data: thumbnail

            the.shared_submit doc, (ok) ->
              status.removeClass 'saving'
              status.addClass if ok then 'saved' else 'failed'

            return false

Login widget
============

Shows the login prompt and options to login using Facebook and Twitter.

      login: (the) ->
        the.widget.html render ->
          section '.login', ->
            form '.form-signin', ->
              label '.input-group.margin-bottom-sm', ->
                span '.input-group-addon', -> i '.fa.fa-envelope-o.fa-fw'
                input '.username.form-control',
                  type:'email'
                  placeholder:texts.email[the.user.language]
              label '.input-group', ->
                span '.input-group-addon', -> i '.fa.fa-key.fa-fw'
                input '.password.form-control',
                  type:'password'
                  placeholder:texts.password[the.user.language]
              input '.btn.btn-lg.btn-primary.btn-block',
                type:'submit'
                value:texts.login_submit[the.user.language]
              div '.notification'
              a href:'/_app/facebook-connect', ->
                span '.facebook-login.btn.btn-lg.btn-primary.btn-block', ->
                  span texts.login_with[the.user.language]
                  i '.fa.fa-facebook'
              a href:'/_app/twitter-connect', ->
                span '.twitter-login.btn.btn-lg.btn-primary.btn-block', ->
                  span texts.login_with[the.user.language]
                  i '.fa.fa-twitter'

Form submission for internal users.

        connect_handler = (res) ->
          if not res.ok
            the.widget.find('.notification').text texts.login_error[the.user.language]
            return

          if not res.body.ok
            the.widget.find('.notification').text texts.login_failed[the.user.language]
            return

          the.session.user = res.body.uuid
          the.router.dispatch ''

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
          .end connect_handler
          return false

        console.log "View login is ready"

Register widget
===============

      register: (the) ->
        the.widget.html render ->
          section '.register', ->
            form '.form-register', ->
              label '.input-group.margin-bottom-sm', ->
                span '.input-group-addon', -> i '.fa.fa-envelope-o.fa-fw'
                input '.username.form-control',
                  type:'email'
                  placeholder:texts.email[the.user.language]
              label '.input-group', ->
                span '.input-group-addon', -> i '.fa.fa-key.fa-fw'
                input '.password.form-control',
                  type:'password'
                  placeholder:texts.password[the.user.language]
              input '.btn.btn-lg.btn-primary.btn-block',
                type:'submit'
                value:texts.register_submit[the.user.language]
              div '.notification'

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
              if res.body.already_connected
                the_router.dispatch '/login'
                return
              the.widget.find('.notification').text texts.register_failed[the.user.language]
              return

            the.session.user = res.body.uuid
            the.router.dispatch ''

          return false

        console.log "View register is ready"

Toolbox
=======

    {render,input,textarea,section,label,i,img,form,select,option,span,div,a,script,raw} = require 'teacup'
