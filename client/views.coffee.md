These functions are called with:
`widget` -- a newly created component-dom `<div>` or other, empty at startup.
`userdb` -- a db instance to the current user's db
`shareddb` -- a db instance (read-only in most cases)
`private_submit` -- save a document into the private database, callback receives true if success
`store` -- the `store` record in `shareddb` when online, `userdb` when offline
`user` -- the `profile` record for the user (found in their `userdb`)

    pflock = require 'pflock'
    $ = require 'dom'

    texts =
      submit_response:
        fr: "J'ai répondu"
        en: "I answered"

    module.exports = widgets =

Texte administrable (welcome text)
==================================

      welcome_text: (the) ->
        if the.store.welcome_text?
          the.widget.text the.store.welcome_text[the.user.language]

Twitter feeds
=============

      twitter_feeds: (the) ->
        if the.store.twitter_username? and the.store.twitter_widget_id?
          the.widget.forEach (el) ->
            window.twttr?.widgets.createTimeline the.store.twitter_widget_id, el, -> console.log 'timeline done'

Questions
=========

We only list questions a given user did not already submit.

      questions: (the) ->

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

            el.forEach (el) ->
              bindings = pflock el, {answer}
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

Toolbox
=======

    {render,input,select,option,span,div,a,script,raw} = require 'teacup'
