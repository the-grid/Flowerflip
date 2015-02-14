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

    # Building for browser
    coffee:
      helloworld:
        options:
          bare: true
        expand: true
        cwd: 'examples/helloworld'
        src: ['**/*.coffee']
        dest: 'browser/examples/helloworld/'
        ext: '.js'
      lib:
        options:
          bare: true
        expand: true
        cwd: 'lib'
        src: ['**/*.coffee', '../index.coffee']
        dest: 'browser/lib/'
        ext: '.js'
      spec:
        options:
          bare: true
        expand: true
        cwd: 'spec'
        src: ['**/*.coffee']
        dest: 'browser/spec/'
        ext: '.js'

    browserify:
      helloworld:
        src: [ 'browser/examples/helloworld/index.js' ],
        dest: './browser/dist/helloworld.js',
        options:
          browserifyOptions:
            standalone: 'helloworld'
      lib:
        src: [ 'browser/index.js' ],
        dest: './browser/dist/flowerflip.js',
        options:
          browserifyOptions:
            standalone: 'flowerflip'
      spec:
        src: [ 'browser/spec/*.js' ],
        dest: './browser/dist/spec.js',
        options:
          browserifyOptions:
            standalone: 'spec'

    # BDD tests on browser
    mocha_phantomjs:
      all:
        options:
          output: 'spec/result.xml'
          reporter: 'spec'
          urls: ['spec/runner.html']

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'
  @loadNpmTasks 'grunt-mocha-phantomjs'

  # Grunt plugins for deploying layout filter
  @loadNpmTasks 'grunt-contrib-coffee'
  @loadNpmTasks 'grunt-browserify'

  @registerTask 'build-helloworld', ['coffee:helloworld', 'browserify:helloworld']
  @registerTask 'build-lib', ['coffee:lib', 'browserify:lib']

  @registerTask 'build', ['build-helloworld', 'build-lib']

  @registerTask 'test', [
    'coffeelint'
    'mochaTest'
    'build'
    'coffee:spec'
    'browserify:spec'
    'mocha_phantomjs'
  ]
  @registerTask 'default', ['test']
