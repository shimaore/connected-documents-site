    config = require '/usr/local/etc/proxy.json'
    crypto = require 'crypto'
    request = require 'superagent'
    UUID = require 'uuid'
    PouchDB = require 'pouchdb'
    USER_PREFIX = 'org.couchdb.user'

These access CouchDB with elevated priviledges.

    auth_db = new PouchDB [config.base_url,'_users'].join '/'
    shared_db = new PouchDB [config.base_url,'public'].join '/'

    module.exports = create_user_account = (options,next) ->
      {username,password,validated} = options

      auth_id = [USER_PREFIX,username].join ':'

Create user record in `auth_db`
===============================

      # Note: properly created record will have a 'created:true' field.
      create_user = (next) ->
        auth_db.get auth_id, (error,doc) ->
          # Shortcut the case where the account was created fine.
          if doc?.created
            return next null, uuid:doc.user_uuid, created:true, validated:doc.validated

          if error?
            # FIXME Assumes it is because the document doesn't exist.
            console.dir auth_db_get:error
            uuid = new UUID()
          else
            # Document exists, but creation failed for some reason.
            uuid = doc.user_uuid

          user_record =
            type: 'user'
            _id: auth_id
            _rev: doc?._rev
            user: username
            password: password
            validated: validated ? false
            user_uuid: uuid
            roles: [
              'user'
            ]

          # Create user record in auth
          auth_db
          .put user_record
          .then ->
            next null, uuid:uuid, created:false, validated:user_record.validated
          .catch (error) ->
            next auth_db_put:error, {}

Main body for `create_user_account`
===================================

      create_user (error,{uuid,created,validated}) ->
        if error? then return next create_user:error
        # Shortcut
        if created then return next null, uuid

        create_user_db username, uuid, (error) ->
          if error? then return next create_user_db:error

          mark_created = (auth_id,next) ->
            auth_db.get auth_id, (error,doc) ->
              if error? then return next auth_db_get:error

              doc.created = true

              auth_db
              .put doc
              .then ->
                next null, uuid
              .catch (error) ->
                next auth_db_put:error

          if validated or options.validated
            mark_created next
          else
            send_validation_email username, (error) ->
              if error? then return next send_validation_email:error
              mark_created next


    create_user_db = (username,uuid,next) ->
      # Create user DB
      # Note: since the base_url has admin auth, PouchDB will handle the creation for us.
      user_db = new PouchDB [config.base_url,uuid].join('/')
      # TODO initial replication ?

      user_db.get 'profile', (error,doc) ->
        # Shortcut the case this was created fine.
        if doc?.uuid?
          next null

        user_db_security =
          members:
            names: [username]
            roles: ['userdb_reader','userdb_writer']

        request
        .put [config.base_url,uuid,'_security'].join('/')
        .send user_db_security
        .end (res) ->
          if not res.ok then return next user_db_security_put:res

          my_profile =
            _id: 'profile'
            uuid: uuid
            username: username

          user_db
          .put my_profile
          .then ->
            next null
          .catch (error) ->
            next user_db_put:error

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
