#!/usr/bin/coffee --literate

This is the main command line interface, all about code
generation which is a lot easier here than in shell.

    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    peg = require 'pegjs'
    _ = require 'lodash'
    pkg = require(path.join(__dirname, "../package.json"))
    grammar = String(fs.readFileSync path.join(__dirname, './orders.grammar'))
    parser = peg.buildParser grammar
    doc = """
    #{pkg.description}

    Usage:
      generate autodeploy <orderfile>
      generate publication <orderfile>
      generate -h | --help | --version

    Notes:

    """
    options = docopt doc, version: pkg.version

    if options.autodeploy
      source = String(fs.readFileSync options['<orderfile>'])
      statements = _.flatten(parser.parse(source))
      order = options['<orderfile>']
      repo = _(statements)
          .filter((x) -> x.autodeploy)
          .last()?.autodeploy
      console.log "initctl start starphleet_autodeploy order='#{order}' repository='#{repo}'"
    if options.publication
      console.log 'p', options['<orderfile>']
