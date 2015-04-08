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
          #grep: 'alt layout'

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
    browserify:
      helloworld:
        options:
          transform: [
            ['coffeeify', {global: true}]
          ]
          browserifyOptions:
            extensions: ['.coffee']
            standalone: 'helloworld'
        files:
          'browser/dist/helloworld.js': ['examples/helloworld/index.coffee']
      lib:
        options:
          transform: [
            ['coffeeify', {global: true}]
          ]
          browserifyOptions:
            extensions: ['.coffee']
            standalone: 'flowerflip'
        files:
          'browser/dist/flowerflip.js': ['index.coffee']
      spec:
        options:
          transform: [
            ['coffeeify', {global: true}]
          ]
          browserifyOptions:
            extensions: ['.coffee']
            standalone: 'spec'
        files:
          'browser/dist/spec.js': ['spec/*.coffee']

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
  @loadNpmTasks 'grunt-browserify'

  @registerTask 'build-helloworld', ['browserify:helloworld']
  @registerTask 'build-lib', ['browserify:lib']

  @registerTask 'build', ['build-lib', 'build-helloworld']

  @registerTask 'test', [
    'coffeelint'
    'mochaTest'
    'build'
    'browserify:spec'
    'mocha_phantomjs'
  ]
  @registerTask 'default', ['test']
