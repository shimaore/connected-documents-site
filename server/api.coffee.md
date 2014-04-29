    zappa = require 'zappajs'
    UUID = require 'uuid'
    request = require 'superagent'
    PouchDB = require 'pouchdb'
    config = require '/usr/local/etc/proxy.json'

    USER_PREFIX = 'org.couchdb.user'

    # TODO find promise-based way of doing the pouch stuff (no error/res stuff.. BUT need yield support in coffeescript)

    zappa config, ->

      auth_db = new PouchDB [config.base_url,'_users']
      shared_db = new PouchDB [config.base_url,'public']

      @use 'logger'

      # TODO
      # Note: it's probably oauth. Let CouchDB auth for us.
      # (Use the "behind couchdb auth" scheme. -- except for initial registration everything must be authed by CouchDB, and we sit behind it so we can access its session cookie. Write middleware to validate the session cookie with CouchDB.)
      @post '/_app/twitter-connect', ->
        # pas besoin de mail de validation
        twitter_connect (ok) ->
          if not ok then return @json error:'failed'

          create_user_account {username,password,validated:true}, (error,uuid) ->
            @session.user = uuid

            @json
              ok: true
              uuid: uuid

      @post '/_app/facebook-connect', ->

        username = @body.authResponse.userID

        # pas besoin de mail de validation
        facebook_connect (ok) ->
          if not ok then return @json error:'failed'

          create_user_account {username,password,validated:true}, (error,uuid) ->
            @session.username = username

            @json
              ok: true
              uuid: uuid

      # FIXME this is probably part of hoodiehq already?
      @post '/_app/register', ->

        if @session.user
          return @json already_connected: true

        username = @body.username
        password = @body.password

        create_user_account {username,password}, (error,uuid) ->
          if error then return @json {error}

          @session.user = uuid

          @json
            ok: true
            uuid: uuid

      create_user_account = (options,next) ->
        {username,password,validated} = options

        uuid = new UUID()

        auth_id = [USER_PREFIX,username].join ':'

        # FIXME try to locate record first and properly handle dups.
        # Note: properly created record will have a 'created:true' field.
        # Create user record in auth
        user_record =
          type: user
          _id: auth_id
          user: username
          password: password
          validated: validated
          user_uuid: uuid
          roles: [
            'user'
          ]

        # auth_db.get user_record, (error,res)

        auth_db.put user_record, (error,res) ->

          # Create user DB
          user_db = new PouchDB [config.base_url,uuid].join('/')

          # TODO initial replication ?

          my_profile =
            _id: 'profile'
            uuid: uuid
            username: username

          used_db.put my_profile, (error,res) ->
            if error then return next {error}

            user_db_security =
              members:
                names: [username]
                roles: ['userdb_reader','userdb_writer']

            user_db.security user_db_security, (error) ->
              if error then return next {error}

              send_validation_email username, (error) ->
                if error then return next {error}

                auth_db.get auth_id, (error,doc) =>
                  if error then return next {error}

                  doc.created = true

                  auth_db.put doc, (error) =>
                    if error then return next {error}
                    next null, uuid

      @include './couch_proxy'
