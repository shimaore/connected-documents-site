    config = require '/usr/local/etc/proxy.json'
    process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = '0'
    PouchDB = require 'pouchdb'
    fs = require 'fs'
    id = '_design/site'

    db = new PouchDB [config.base_url,'public'].join '/'
    db.get id, (err,doc) ->
      if err then return console.log get:err, got:doc
      if doc?._rev?
        console.log "Updating rev #{doc._rev}"
        db.putAttachment id, 'index.html', doc._rev, fs.readFileSync('test/index.html'), 'text/html', (err,res) ->
          if err then return console.log put1:err
          if res.ok and res.rev
            db.putAttachment id, 'site.js', res.rev, fs.readFileSync('test/site.js'), 'application/javascript', (err,res) ->
              if err then return console.log put2:err
              if res.ok and res.rev
                console.log "OK"

