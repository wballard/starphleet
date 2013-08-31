#!/usr/bin/coffee --literate

This is just here as a junction box help script. This doesn't really
run by itself, it just stands in for a real command via CMD through
Docker.

    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    pkg = require(path.join(__dirname, "../package.json"))
    doc = """
    #{pkg.description}

    Usage:
      join
      phleet -h | --help | --version

    Notes:

    """
    options = docopt doc, version: pkg.version
