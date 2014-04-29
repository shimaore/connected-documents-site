    request = require 'request'
    config = require '/usr/local/etc/proxy.json'

    @include = ->

Reverse proxy towards CouchDB

      make_proxy = (proxy_base) ->
        return ->
          proxy = request
            uri: proxy_base + @request.url
            method: @request.method
            headers: @request.headers
            jar: false
            followRedirect: false
            timeout: 1000
          @request.pipe proxy
          proxy.pipe @response
          return

      couchdb_proxy = make_proxy config.couchdb_url ? 'http://127.0.0.1:5984'

      # FIXME restrict _all_dbs|_config to admins?

      couchdb_urls = /^\/(_session|_users|_uuids|_utils|_all_dbs|_config|[^_][a-zA-Z0-9_-]*)($|\/)/
      @get  couchdb_urls, couchdb_proxy
      @post couchdb_urls, couchdb_proxy
      @put  couchdb_urls, couchdb_proxy
      @del  couchdb_urls, couchdb_proxy
