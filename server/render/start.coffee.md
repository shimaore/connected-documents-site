Start rendering using SlimerJS

    module.exports = ->
      path = require 'path'
      {spawn} = require 'child_process'

      cl = spawn '/usr/bin/xvfb-run', [
        '/usr/bin/xulrunner-24.0'
        '-app'
        path.join __dirname,'slimerjs-0.9.1','application.ini'
        '-no-remote'
        path.join __dirname,'server.js'
      ]

      cl.stderr.on 'data', (data) ->
        console.log 'stderr: '+data

      cl.stdout.on 'data', (data) ->
        console.log 'stdout: '+data

      cl.on 'close', (code) ->
        console.log 'Renderer exited with '+code

      return cl
