module.exports = (grunt) ->

  pkg = grunt.file.readJSON 'package.json'

  grunt.initConfig
    pkg: pkg

    browserify:
      dist:
        options:
          transform: ['coffeeify','debowerify','decomponentify', 'deamdify', 'deglobalify','rfileify']
        files:
          'dist/<%= pkg.name %>.js': 'client/main.coffee.md'

    clean:
      dist: ['lib/', 'dist/']
      modules: ['node_modules/', 'bower_components/', 'components/']
      test: ['test/*.js']

    uglify:
      dist:
        files:
          'dist/<%= pkg.name %>.min.js': 'dist/<%= pkg.name %>.js'

    copy:
      test:
        expand: true
        cwd: 'dist/'
        src: ['*.js']
        dest: 'test/'

    watch:
      dist:
        files: 'src/*.coffee.md'
        tasks: ['browserify','copy:test','notify:watch']

    notify:
      watch:
        options:
          title: 'Task completed'
          message: 'Build is complete.'

  grunt.loadNpmTasks 'grunt-shell'
  grunt.loadNpmTasks 'grunt-browserify'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-notify'
  grunt.registerTask 'default', 'clean:dist browserify uglify:dist'.split ' '
  grunt.registerTask 'test', 'default clean:test copy:test'.split ' '
