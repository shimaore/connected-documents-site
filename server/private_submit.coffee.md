    config = require '/usr/local/etc/proxy.json'
    PouchDB = require 'pouchdb'
    UUID = require 'uuid'

    @include = ->

      bodyParser = @express.bodyParser()

Private submit
==============

Submit a document into the private database.

      private_db = new PouchDB [config.base_url,'private'].join '/'

      @post '/_app/private_submit', [bodyParser], ->
        doc = @body

Ensure unicity by appending the user's UUID, unless they requested anonymity.
(CouchDB may not validate some documents anonymously, which is expected.)

        uuid = if doc.anonymous then UUID.v4() else @session.user
        doc._id = [doc._id,uuid].join ':'

The document is normally validated by CouchDB, but we ensure that they are brand new ones.

        delete doc._rev

        private_db
        .put doc
        .then =>
          @json ok:true
        .catch (error) =>
          @json {error}

FIXME: figure out how to move attachments.
