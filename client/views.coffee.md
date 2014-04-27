These functions are called with:
`widget` -- a newly created component-dom `<div>` or other, empty at startup.
`userdb` -- a db instance to the current user's db
`shareddb` -- a db instance (read-only in most cases)
`private_submit` -- save a document into the private database, callback receives true if success
`store` -- the `store` record in `@shareddb` when online, `@userdb` when offline
`user` -- the `profile` record for the user (found in their userdb)

    pflock = require 'pflock'

    widgets =

Texte administrable (welcome text)
==================================

      welcome_text: (the) ->
        if the.store.welcome_text?
          the.widget.text the.store.welcome_text[the.user.language]

Twitter feeds
=============

      twitter_feeds: (the) ->
        if the.store.twitter_name? and the.store.twitter_widget_id?
          the.widget.html render ->
            a class:'twitter-timeline', href:"https://twitter.com/#{the.store.twitter_name}", 'data-widget-id':the.store.twitter_widget_id, "Tweets by @#{the.store.twitter_name}"
            script '''
              !function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+"://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");
            '''

Questions
=========

We only list questions a given user did not already submit.

      questions: (the) ->

        one_question = (q) =>
          # load the answer record
          the.userdb.find 'answer', q.question, (answer) ->
            answer ?= {}

            the.widget.html render ->
              div class:'question', ->
                span question.text

            input =
              switch question.answer_type
                when 'boolean'
                  render -> input type:'checkbox', 'x-bind':'value:/answer/content'
                when 'string'
                  render -> input 'x-bind':'value:/answer/content'
                else
                  render -> select 'x-bind': 'value:/answer/content', ->
                    for o in question.answer_type
                      option value:o, -> o

            the.widget.append input

            the.widget.append render ->
              input type:'checkbox', 'x-bind':'submitted'

            the.widget.forEach (el) ->
              bindings = pflock el, {answer}
              bindings.on 'changed', (data) ->
                the.userdb.update 'answer', q.question, data, (doc,old_doc) ->
                  if not doc? 
                    bindings.toDocument old_doc
                    return
                  if doc.submitted
                    private_submit data, (ok) ->
                      if ok
                        the.widget.hide()
                      else
                        doc.submitted = false
                        bindings.toDocument doc


        user_language = @user.language

        the.userdb.all 'answer', (answers) ->
          answered_questions = answers
            .filter (_) -> not _.submitted
            .map (_) -> _.question

          the.shareddb.all 'question', (questions) ->
            for q in questions when q.language is user_language and not q.question in answered_questions
              one_question q

Toolbox
=======

    {render,input,select,option,span,div} = require 'teacup'

    _id = ->
      arguments.join ':'
