This is the main command line interface.


    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    package_json = JSON.parse fs.readFileSync path.join(__dirname, './package.json')
    doc = """
    #{package_json.description}

    Usage:
      phleet join <giturl>
      phleet -h | --help | --version

    Notes:

    """
    options = docopt doc, version: package_json.version
