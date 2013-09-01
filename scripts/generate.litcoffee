#!/usr/bin/coffee --literate

This is the main command line interface, all about code
generation which is a lot easier here than in shell.

    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    peg = require 'pegjs'
    _ = require 'lodash'
    handlebars = require 'handlebars'
    pkg = require(path.join(__dirname, "../package.json"))
    grammar = String(fs.readFileSync path.join(__dirname, './orders.grammar'))
    parser = peg.buildParser grammar
    doc = """
    #{pkg.description}

    Usage:
      generate autodeploy <orderfile>
      generate servers <orderfile>
      generate -h | --help | --version

    Notes:

    """
    options = docopt doc, version: pkg.version
    source = String(fs.readFileSync options['<orderfile>'])
    statements = _.flatten(parser.parse(source))
    order = options['<orderfile>']

    if options.autodeploy
      repo = _(statements)
          .filter((x) -> x.autodeploy)
          .last()?.autodeploy
      console.log "initctl start starphleet_autodeploy order='#{order}' repository='#{repo}'"
    if options.servers
      template = """
      {{#each .}}
      server {
        listen {{this}};
        include publications/{{this}}.*.conf;
      }
      {{/each}}
      """
      servers = _(statements)
        .filter((x) -> x.publish)
        .groupBy((x) -> x.publish.to)
        .keys()
        .value()
      console.log handlebars.compile(template)(servers)
