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
          #grep: 'Hello World'

    # Coding standards
    coffeelint:
      components: [
        '*.coffee'
        'lib/*.coffee'
      ]
      options:
        'max_line_length':
          'level': 'ignore'

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'

  @registerTask 'test', ['coffeelint', 'mochaTest']
  @registerTask 'default', ['test']
