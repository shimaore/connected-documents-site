    config = require '/usr/local/etc/proxy.json'
    process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = '0'
    PouchDB = require 'pouchdb'
    fs = require 'fs'
    async = require 'async'
    id = '_design/site'

    files = [
      'index.html test/index.html text/html'
      'index.css  test/index.css text/css'
      'site.js    test/site.js   application/javascript'
      'css/bootstrap.min.css       ../frifri-bootstrap/dist/css/bootstrap.min.css text/css'
      'css/bootstrap-theme.min.css ../frifri-bootstrap/dist/css/bootstrap-theme.min.css text/css'
      # 'fonts/glyphicons-halflings-regular.eot'
      # 'fonts/glyphicons-halflings-regular.ttf'
      # 'fonts/glyphicons-halflings-regular.woff'
      'js/bootstrap.min.js         ../frifri-bootstrap/dist/js/bootstrap.min.js application/javascript'
    ].map (x) ->
      [name,src,type] = x.split /\s+/
      {name,src,type}

    rev = null
    put_attachment = (item,next) ->
      console.log "rev = #{rev} item = #{item}"
      db.putAttachment id, item.name, rev, fs.readFileSync(item.src), item.type, (err,res) ->
        if not err and res.ok and res.rev
          rev = res.rev
          next null
        else
          next error:err

    db = new PouchDB [config.base_url,'public'].join '/'
    db.get id, (err,doc) ->
      if err then return console.log get:err, got:doc
      if doc?._rev?
        rev = doc._rev

      async.eachSeries files, put_attachment
