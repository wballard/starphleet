This is the main command line interface.


    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    require('shellscript').globalize()
    package_json = JSON.parse fs.readFileSync path.join(__dirname, './package.json')
    doc = """
    #{package_json.description}

    Usage:
      phleet join <giturl>
      phleet -h | --help | --version

    Notes:

    """
    options = docopt doc, version: package_json.version

    if options.join
      shell('rm -rf /var/starphleet/headquarters')
      shell("git clone #{options['<giturl>']} /var/starphleet/headquarters")
      shell("touch /var/starphleet/headquarters.neworders")
