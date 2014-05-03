    PouchDB = require 'pouchdb'

    @include = ->

      bodyParser = @express.bodyParser()

Private submit
==============

Submit a document into the private database.

      private_db = new PouchDB [config.base_url,'private'].join '/'

      @post '/_app/private_submit', [bodyParser], ->
        doc = @body

The document is entirely validated by CouchDB, but we ensure that they are brand new ones.

        delete doc._rev

        private_db
        .put doc
        .then ->
          @json ok:true
        .catch (error) ->
          @json {error}

FIXME: figure out how to move attachments.
