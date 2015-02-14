module.exports = ->
  # Project configuration
  @initConfig
    pkg: @file.readJSON 'package.json'

    # BDD tests on Node.js
    mochaTest:
      nodejs:
        src: ['spec/*.coffee']
        options:
          reporter: 'spec'
          require: 'coffee-script/register'
          #grep: 'branches'

    # Coding standards
    coffeelint:
      components: [
        '*.coffee'
        'lib/*.coffee'
      ]
      options:
        'max_line_length':
          'level': 'ignore'

    # Building layout filter
    coffee:
      helloworld:
        options:
          bare: true
        expand: true
        cwd: 'examples/helloworld'
        src: ['**/*.coffee']
        dest: 'browser/build/helloworld/'
        ext: '.js'

    browserify:
      helloworld:
        src: [ 'browser/build/helloworld/index.js' ],
        dest: './browser/dist/helloworld.standalone.js',
        options:
          browserifyOptions:
            standalone: 'helloworld'


  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'

  # Grunt plugins for deploying layout filter
  @loadNpmTasks 'grunt-contrib-coffee'
  @loadNpmTasks 'grunt-browserify'

  @registerTask 'build-helloworld', ['coffee:helloworld', 'browserify:helloworld']

  @registerTask 'build', ['build-helloworld']

  @registerTask 'test', ['coffeelint', 'mochaTest']
  @registerTask 'default', ['test']
