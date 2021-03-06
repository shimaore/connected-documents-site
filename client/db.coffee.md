Note: historically I've been using ':' as separator for ID components. HoodieHQ uses '/' (see https://github.com/hoodiehq/hoodie.js/blob/master/src/lib/store/remote.js#L517 )

    _id = (type,key) ->
      if key?
        [type,key].join ':'
      else
        type

Rewrite function into wrapped text (this works around some limitations in how CouchDB deals with JavaScript).

    fun = (f) -> "(#{f})"

    PouchDB = require 'pouchdb'

    module.exports = class db

      constructor: (@name) ->
        console.log "PouchDB for #{@name}"
        @pouch = new PouchDB @name

      _id: _id

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
          new_doc[k] = update[k] for own k of update when not k.match /^_/
          new_doc._id ?= _id type, id
          # Follow the HoodieHQ fields (see https://github.com/hoodiehq/hoodie.js/blob/master/src/lib/store/api.js#L144 )
          new_doc.type ?= type
          new_doc.id ?= id
          @pouch.put new_doc, (err,res) ->
            if err or not res.rev?
              cb? null, old_doc
            else
              new_doc._rev = res.rev
              cb? new_doc, old_doc

Dynamically push design documents.

      add_view: (name,{map,reduce},cb) ->
        [design_doc,view_name] = name.split '/'
        update = (doc) =>
          doc.views ?= {}
          view =
            map: fun map
          view.reduce = fun reduce if reduce?
          doc._views[view_name] = view
          @pouch
            .put doc
            .then cb

        @pouch
          .get "_design/#{design_doc}"
          .then update
          .catch (err) ->
            # FIXME Assumes error is missing doc.
            update _id: "_design/#{design_doc}"
