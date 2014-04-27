    _id = -> arguments.join ':'

    PouchDB = require 'pouchdb'

    module.exports = class db

      constructor: (@name) ->
        @db = new PouchDB @name

      all: (type,cb) ->
        if type?
          @db.allDocs startkey: "#{type}:", endkey: "#{type};", include_docs: true, (err,res) ->
            if err or not res?
              cb? []
            else
              cb? res.rows.map (r) -> r.doc

      find: (type,id,cb) ->
        @db.get _id(type,id), (err,doc) ->
          if err or not doc?
            cb? null
          else
            cb? doc

      update: (type,id,update,cb) ->
        @find type, id, (old_doc) =>
          new_doc = {}
          if old_doc?
            new_doc[k] = old_doc[k] for own k of old_doc
          new_doc[k] = update[k] for own k of update
          new_doc._id ?= _id type, id
          @db.put new_doc, (err,res) ->
            if err or not res.rev?
              cb? null, old_doc
            else
              new_doc._rev = res.rev
              cb? new_doc, old_doc
