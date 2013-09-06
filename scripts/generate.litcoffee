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
      generate run <orderfile>
      generate info <name> <orderfile> <containerfile>
      generate containerPorts <containerfile>
      generate servers <infofile>...
      generate containers <infofile>...
      generate -h | --help | --version

    Notes:

    """
    options = docopt doc, version: pkg.version

    statements = ->
      source = String(fs.readFileSync options['<orderfile>'])
      _.flatten(parser.parse(source))

    if options.repository
      process.stdout.write _(statements())
          .filter((x) -> x.autodeploy)
          .last()?.autodeploy or ''
    if options.run
      process.stdout.write _(statements())
          .filter((x) -> x.command)
          .last()?.command or ''
    if options.containers
      for infofile in options['<infofile>']
        try
          content = JSON.parse(String(fs.readFileSync(infofile)))
          for c in content
            process.stdout.write c.container + ' '
        catch e
          #eat this for now, docker is mixing streams
          #console.error e
    if options.servers
      buffer = []
      for infofile in options['<infofile>']
        try
          content = JSON.parse(String(fs.readFileSync(infofile)))
          for c in content
            buffer.push c
        catch e
          #eat this for now, docker is mixing streams
          console.error e
      context = []
      for port, publications of _.groupBy(buffer, (x) -> x.hostPort)
        context.push
          port: port
          publications: publications
      template = """
      {{#each .}}
      server {
        listen {{port}};
        {{#each publications}}
        location {{url}} {
          # Path rewriting to hide mount prefix
          rewrite {{url}}(.*) /$1 break;
          proxy_pass http://127.0.0.1:{{containerPort}};
          add_header X-DOCKER-CONTAINER {{container}};
          # WebSocket support (nginx 1.4)
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";

          proxy_redirect off;
        }
        {{/each}}
      }
      {{/each}}
      """
      console.log handlebars.compile(template)(context)
    if options.containerPorts
      infos = JSON.parse(String(fs.readFileSync options['<containerfile>']))
      for info in infos
        console.log info.containerPort
    if options.info
      infos = JSON.parse(String(fs.readFileSync options['<containerfile>']))
      publications = _.filter(statements(), (x) -> x.publish)
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
                name:  options['<name>']
      console.log JSON.stringify(mapped)
