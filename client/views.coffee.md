The functions are called with:
`widget` -- a newly created jquery `<div>` or other, empty at startup.
`userdb` -- a DB for the current user's db
`shareddb` -- a DB for the shared db (read-only in most cases)
`private_submit` -- save a document into the private database, callback receives true if success
`shared_submit` -- save a document into the shared database, callback receives true if success
`store` -- the `store` record in `shareddb` when online, `userdb` when offline
`user` -- the `profile` record for the user (found in their `userdb`)

    pflock = require 'pflock-browserify'
    $ = require 'jquery'
    bootstrap = (require './vendor/bootstrap')($)
    request = require 'superagent'
    crypto = require 'crypto'
    throttle = require './throttle.coffee.md'

    thumbnail_content_type = 'image/png'
    seconds = 1000

    website_image = (url,cb) ->
      request
        .post '/_app/website-image'
        .send {url}
        .accept 'json'
        .end (res) ->
          if res.ok
            cb res.body.content

    texts =
      languages:
        fr: 'Français'
        en: 'English'
      language:
        fr: 'Langue'
        en: 'Language'
      menu:
        fr: 'Menu'
        en: 'Menu'
      home:
        fr: 'Accueil'
        en: 'Main'
      my_account:
        fr: 'Mon compte'
        en: 'My account'
      reading_club:
        fr: 'Club de lecture'
        en: 'Reading club'
      profile:
        fr: 'Profil'
        en: 'Profile'
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
      content_submission:
        fr: 'Suggérer des lectures'
        en: 'Suggest readings'
      submit_done:
        fr: "Fini"
        en: "Done"
      submit_response:
        fr: "J'ai répondu"
        en: "I answered"
      email:
        fr: 'Address de mail'
        en: 'Email address'
      password:
        fr: 'Mot de passe'
        en: 'Password'
      show_login:
        fr: 'Je me suis déjà connecté(e)'
        en: "I've been here before"
      show_register:
        fr: 'Première connexion'
        en: 'First time here'
      login_submit:
        fr: 'Login'
        en: 'Login'
      register_with:
        fr: 'Créer un compte avec '
        en: 'Register using '
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
      summary:
        fr: 'Résumé'
        en: 'Summary'
      shared_content:
        fr: 'Contenu partagé'
        en: 'Shared content'
      participate_in_survey:
        fr: "Participer à l'étude"
        en: 'Participate in survey'
      submit_answers:
        fr: 'Fini'
        en: 'Done'
      content_type:
        fr: 'Type de contenu'
        en: 'Type'
      content_type_book:
        fr: 'Livre ou ebook'
        en: 'Paper book or e-book'
      content_type_url:
        fr: 'Site ou page web'
        en: 'Site or web page'
      content_type_offered:
        fr: 'PDF'
        en: 'PDF'

    module.exports = widgets =

Texte administrable (welcome text)
==================================

      welcome_text: (the) ->
        if the.store.welcome_text?
          the.widget.html render ->
            div '.color-grey.welcome', the.store.welcome_text[the.user.language]

Logout button
=============

      logout: (the) ->
        the.widget.html render ->
          span '.username', the.user.name ? the.session.display
          button '.logout.btn.btn-lg.btn-primary', texts.logout[the.user.language]

        the.widget.on 'click', '.logout', ->
          the.router.dispatch '/logout'

Top (logo)
==========

      top: (the) ->
        the.widget.html render ->
          a href:'#/', ->
            img ".logo.#{if the.session.user? then 'logged-in' else 'logged-out'}", src:"logo-#{the.user.language}.png"

        if the.session.user?
          the.widget.addClass 'col-md-5'

Menu
====

      menu: (the) ->
        the.widget.html render ->
          div '.menu .btn-group-vertical', ->
            for name in 'home,my_account,reading_club,logout'.split ','
              a '.btn.btn-default', href:"#/#{name}", texts[name][the.user.language]

        ($ '.dropdown-toggle').dropdown()

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

        the.shareddb.all 'question', (questions) -> the.userdb.all 'answer', (answer_docs) ->
          answers = {}
          answers[doc.id] = doc for doc in answer_docs

          any_questions = false
          container = $ '<div/>'
          for q in questions when q.language is the.user.language and not answers[q.question]?.submitted
            el = $ render ->
              div '.form-question'
            widgets.one_question the, el, q, answers[q.question] ? {}
            any_questions = true
            container.append el

          container.append render ->
            button '.submit-answers', texts.submit_answers[the.user.language]

          if any_questions
            the.widget.html render ->
              div '.questions', ->
                if the.store.questions_text?
                  div '.questions-text.color-grey', the.store.questions_text[the.user.language]
                button '.participate_in_survey.btn.btn-lg.btn-primary', texts.participate_in_survey[the.user.language]

            the.widget.on 'click', '.participate_in_survey', ->
              the.widget
                .find 'button'
                .remove()
              the.widget.append container

Simulate the user clicking on all the "submit-answer" buttons.

              container.on 'click', '.submit-answers', ->
                the.widget
                  .find '.submit-answer'
                  .click()
                the.widget
                  .find 'button'
                  .remove()
                the.widget
                  .find '.questions-text'
                  .remove()

One question
============

      one_question: (the,el,q,answer) ->

        # FIXME keep_anonymous

        do ->
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
              button '.submit-answer .btn', -> i '.fa.fa-times'
              raw input_html

          el.each ->
            bindings = pflock this, {answer}

            changed = (data) ->
              the.userdb.update 'answer', q.question, data, (doc,old_doc) ->
                bindings.toDocument {answer: doc ? old_doc}
                el
                  .find 'button i'
                  .removeClass 'fa-refresh fa-spin'
                  .addClass 'fa-times'
                if doc?.submitted
                  el.hide()
                return

            bindings.on 'changed', ->
              changed bindings.data.answer

            el.on 'click', '.submit-answer', ->
              el
                .find 'button i'
                .removeClass 'fa-times'
                .addClass 'fa-refresh fa-spin'
              data = bindings.data.answer
              the.private_submit data, (ok) ->
                data.submitted = ok
                changed data

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
              div '.form-group', ->
                input type:'checkbox', 'x-bind':'value:/profile/publish/profile'
                label texts.publish_profile[the.user.language]
              div '.form-group', ->
                input type:'checkbox', 'x-bind':'value:/profile/publish/description'
                label texts.publish_description[the.user.language]
              div '.form-group', ->
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
              button '.done.btn.btn-lg.btn-primary', texts.submit_done[the.user.language]

        the.widget.on 'click', '.done', ->
          the.router.dispatch '/'

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

        content_types =
          if 'admin' in the.session.roles
            ['book','url','offered']
          else
            ['book','url']

        the.widget.html render ->
          section '.content_submission', ->
            form '.form-submission', ->

Content type

              div '.form-group', ->
                label texts.content_type[the.user.language]
                select '.content_type.form-control',
                  required:true,
                  'x-bind':'value:/content_type', ->
                    for t in content_types
                      option t, texts["content_type_#{t}"][the.user.language]

Title

              div '.form-group', ->
                label texts.title[the.user.language]
                input '.title.form-control',
                  type:'text', required:true
                  'x-bind':'value:/title'

Author

              div '.form-group', ->
                label texts.author[the.user.language]
                input '.author.form-control',
                  type:'text', required:true
                  'x-bind':'value:/author'

Summary

              div '.form-group', ->
                label texts.summary[the.user.language]
                textarea '.summary.form-control',
                  required:true
                  'x-bind':'value:/summary'

Thumbnail / photo

              div '.form-group', ->
                i '.loading-thumbnail .fa.fa-spin'
                img '.thumbnail', src:'coeur.png'

URL

              div '.form-group.on_url', ->
                label texts.url_link[the.user.language]
                input '.url.form-control',
                  type:'url', required:true
                  'x-bind':'value:/url'
                  placeholder:'http://'

              input '.btn.btn-default',
                type:'submit', value:texts.submit[the.user.language]
              div '.notification'

        the.widget.find('form').each ->
          el = this
          doc =
            type: 'content'
            content_type: 'book'
            submitted_by: the.session.user

          bindings = pflock el, doc

          bindings.on 'path-changed', (path,value) ->
            switch path
              when '/url'
                $(el)
                  .find '.loading-thumbnail'
                  .addClass 'fa-refresh'
                throttle 'website_image', 3*seconds, ->
                  website_image value, (img) ->
                    $(el).find('img.thumbnail').attr 'src', "data:#{thumbnail_content_type};base64,#{img}"
                    doc._attachments =
                      thumbnail:
                        content_type: thumbnail_content_type
                        data: img
                    $(el)
                      .find '.loading-thumbnail'
                      .removeClass 'fa-refresh'

          $(el).submit (e) ->
            e.preventDefault()
            $(el)
              .find '.btn'
              .removeClass 'btn-default'
              .addClass 'btn-info'

Compute a proper ID for the document

            h = crypto.createHash 'sha1'

            switch doc.content_type
              when 'book'
                h.update doc.title
                h.update doc.author

              when 'url'
                unless doc.url?
                  console.log "Missing doc.url"
                  # FIXME notify
                  return

                h.update doc.url

              when 'offered'
                h.update doc.title
                h.update doc.author

              else
                console.log "Missing doc.content_type"
                # FIXME
                return

            uuid = h.digest 'hex'
            doc.id = uuid
            doc._id = the.userdb._id 'content', uuid

            the.shared_submit doc, (ok) ->
              $(el)
                .find 'btn'
                .removeClass 'btn-info'
                .addClass if ok then 'btn-success' else 'btn-warning'

              the.router.dispatch '/'

            return false

Login-or-register widget
========================

      login_or_register: (the) ->
        the.widget.html render ->
          section '.login-or-register', ->
            div '.row', ->
              button '.show-register.btn.btn-lg.btn-primary.col-md-4.col-md-offset-1', texts.show_register[the.user.language]
              button '.show-login.btn.btn-lg.btn-primary.col-md-4.col-md-offset-1', texts.show_login[the.user.language]

        the.widget.on 'click', '.show-register', ->
          the.widget.hide()
          $ 'section.register'
            .show()

        the.widget.on 'click', '.show-login', ->
          the.widget.hide()
          $ 'section.login'
            .show()


Login widget
============

Shows the login prompt and options to login using Facebook and Twitter.

      login: (the) ->
        the.widget.html render ->
          section '.login.col-md-6.col-md-offset-2', ->

            div '.row', ->

              a '.link-signin.col-md-5.col-md-offset-1', href:'/_app/facebook-connect', ->
                span '.facebook-login.btn.btn-lg.btn-primary', ->
                  span texts.login_with[the.user.language]
                  i '.fa.fa-facebook'

              a '.link-signin.col-md-5.col-md-offset-2', href:'/_app/twitter-connect', ->
                span '.twitter-login.btn.btn-lg.btn-primary', ->
                  span texts.login_with[the.user.language]
                  i '.fa.fa-twitter'

            div '.row', ->

              form '.form-signin.col-md-10.col-md-offset-1', ->
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

        the.widget
          .find 'section.login'
          .hide()

Form submission for internal users.

        connect_handler = (res) ->
          if not res.ok
            the.widget.find('.notification').text texts.login_error[the.user.language]
            return

          if not res.body.ok
            the.widget.find('.notification').text texts.login_failed[the.user.language]
            return

          the.session.user = res.body.uuid

Update the session data.

          the.router.dispatch '/login'

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
          section '.register.col-md-6.col-md-offset-2', ->

            div '.row', ->

              a '.link-register.col-md-5.col-md-offset-1', href:'/_app/facebook-connect', ->
                span '.facebook-login.btn.btn-lg.btn-primary', ->
                  span texts.register_with[the.user.language]
                  i '.fa.fa-facebook'

              a '.link-register.col-md-5.col-md-offset-7', href:'/_app/twitter-connect', ->
                span '.twitter-login.btn.btn-lg.btn-primary', ->
                  span texts.register_with[the.user.language]
                  i '.fa.fa-twitter'

            div '.row', ->

              form '.form-register.col-md-10.col-md-offset-1', ->
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

        the.widget
          .find 'section.register'
          .hide()

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

Wrappers
========

      toggle_wrapper: (the,name,widget) ->
        w = $ render ->
          div ->
            span '.toggle', ->
              i '.fa.fa-plus-circle'
              text texts[name][the.user.language]

        w.append widget
        widget.hide()
        w.on 'click', '.toggle', ->
          widget.toggle()

        w

Toolbox
=======

    {render,input,button,textarea,section,label,i,img,form,select,option,span,div,a,script,raw,text,ul,li} = require 'teacup'
