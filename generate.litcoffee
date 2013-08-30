
This is the main command line interface, all about code
generation which is a lot easier here than in shell.


    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    package_json = JSON.parse fs.readFileSync path.join(__dirname, './package.json')
    doc = """
    #{package_json.description}

    Usage:
      generate autodeploys <orderfile>
      generate publications <orderfile>
      generate containers <orderfile>
      phleet -h | --help | --version

    Notes:

    """
    options = docopt doc, version: package_json.version

    if options.autodeploys
      console.log 'a', options['<orderfile>']
    if options.publications
      console.log 'p', options['<orderfile>']
    if options.containers
      console.log 'c', options['<orderfile>']
