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
      generate repository <orderfile>
      generate servers <orderfile>
      generate info <orderfile> <infofile>
      generate -h | --help | --version

    Notes:

    """
    options = docopt doc, version: pkg.version
    source = String(fs.readFileSync options['<orderfile>'])
    statements = _.flatten(parser.parse(source))
    order = options['<orderfile>']

    if options.repository
      repo = _(statements)
          .filter((x) -> x.autodeploy)
          .last()?.autodeploy
      process.stdout.write(repo)
    if options.servers
      template = """
      {{#each .}}
      server {
        listen {{this}};
        include {{this}}.*.conf;
      }
      {{/each}}
      """
      servers = _(statements)
        .filter((x) -> x.publish)
        .groupBy((x) -> x.publish.to)
        .keys()
        .value()
      console.log handlebars.compile(template)(servers)
    if options.info
      infos = JSON.parse(String(fs.readFileSync options['<infofile>']))
      publications = _.filter(statements, (x) -> x.publish)
      mapped = []
      for info in infos
        for from, to of (info?.NetworkSettings?.PortMapping?.Tcp or {})
          from = parseInt(from)
          to = parseInt(to)
          for publication in publications
            if publication.publish.from is from
              mapped.push
                container: info.ID
                containerPort: to
                hostPort: publication.publish.to
                url: publication.publish.url
      console.log mapped
