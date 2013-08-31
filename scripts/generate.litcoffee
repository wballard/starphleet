#!/usr/bin/env coffee

This is the main command line interface, all about code
generation which is a lot easier here than in shell.

    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    peg = require 'pegjs'
    _ = require 'lodash'
    package_json = JSON.parse fs.readFileSync path.join(__dirname, './package.json')
    grammar = String(fs.readFileSync path.join(__dirname, './orders.grammar'))
    parser = peg.buildParser grammar
    doc = """
    #{package_json.description}

    Usage:
      generate autodeploy <orderfile>
      generate publication <orderfile>
      generate -h | --help | --version

    Notes:

    """
    options = docopt doc, version: package_json.version

    if options.autodeploy
      console.log 'fuck off'
      source = String(fs.readFileSync options['<orderfile>'])
      statements = _.flatten(parser.parse(source))
      console.log source, statements
      console.log 'a', options['<orderfile>']
    if options.publication
      console.log 'p', options['<orderfile>']
