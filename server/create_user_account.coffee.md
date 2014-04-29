    config = require '/usr/local/etc/proxy.json'
    crypto = require 'crypto'
    request = require 'superagent'
    UUID = require 'uuid'
    PouchDB = require 'pouchdb'
    USER_PREFIX = 'org.couchdb.user'

    # TODO find promise-based way of doing the pouch stuff (no error/res stuff.. BUT need yield support in coffeescript)

These access CouchDB with elevated priviledges.

    auth_db = new PouchDB [config.base_url,'_users']
    shared_db = new PouchDB [config.base_url,'public']

    module.exports = create_user_account = (options,next) ->
      {username,password,validated} = options

      auth_id = [USER_PREFIX,username].join ':'

      create_user (error,uuid) ->
        if error? then return next {error}

        create_user_db username, uuid, (error) ->
          if error? then return next {error}

          mark_created = (auth_id,next) ->
            auth_db.get auth_id, (error,doc) ->
              if error then return next {error}

              doc.created = true

              auth_db.put doc, (error) ->
                if error then return next {error}
                next null

          if options.validated
            mark_created next
          else
            send_validation_email username, (error) ->
              if error? then return next {error}
              mark_created next


    # Note: properly created record will have a 'created:true' field.
    create_user = (auth_id,next) ->
      auth_db.get auth_id, (error,doc) ->
        # Shortcut the case where the account was created fine.
        if doc?.created
          return next null, doc.user_uuid

        if error?
          # FIXME Assumes it is because the document doesn't exist.
          console.dir auth_db_get:error
          uuid = new UUID()
        else
          # Document exists, but creation failed for some reason.
          uuid = doc.user_uuid

        user_record =
          type: user
          _id: auth_id
          _rev: doc?._rev
          user: username
          password: password
          validated: validated
          user_uuid: uuid
          roles: [
            'user'
          ]

        # Create user record in auth
        auth_db.put user_record, (error,res) ->
          if error? then return next {error}
          next null, uuid

    create_user_db = (username,uuid,next) ->
      # Create user DB
      # Note: since the base_url has admin auth, PouchDB will handle the creation for us.
      user_db = new PouchDB [config.base_url,uuid].join('/')

      # TODO initial replication ?

      my_profile =
        _id: 'profile'
        uuid: uuid
        username: username

      user_db.put my_profile, (error,res) ->
        if error then return next {error}

        user_db_security =
          members:
            names: [username]
            roles: ['userdb_reader','userdb_writer']

        request
        .put [config.base_url,uuid,'_security'].join('/')
        .send user_db_security
        .end (res) ->
          if not res.ok then return next res
          next null

    send_validation_email = (username,next) ->
      # TODO implement

      # FIXME returns "always succeeded"
      next null

    make_token = (o) ->
      secret = config.couch_secret
      sum = crypto.createHash 'sha1'
      sum.update secret
      sum.update o.user
      sum.digest 'hex'
