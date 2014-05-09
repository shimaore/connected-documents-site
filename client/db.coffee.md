    _id = (type,key) ->
      if key?
        [type,key].join ':'
      else
        type

    PouchDB = require 'pouchdb'

    module.exports = class db

      constructor: (@name) ->
        console.log "PouchDB for #{@name}"
        @pouch = new PouchDB @name

Add a (HoodieHQ-esque) type-based API to PouchDB.

      all: (type,cb) ->
        if type?
          @pouch.allDocs startkey: "#{type}:", endkey: "#{type};", include_docs: true, (err,res) ->
            if err or not res?
              cb? []
            else
              cb? res.rows.map (r) -> r.doc

      find: (type,id,cb) ->
        @pouch.get _id(type,id), (err,doc) ->
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
          @pouch.put new_doc, (err,res) ->
            if err or not res.rev?
              cb? null, old_doc
            else
              new_doc._rev = res.rev
              cb? new_doc, old_doc
