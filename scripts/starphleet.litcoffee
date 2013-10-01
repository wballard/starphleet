#!/usr/bin/env coffee --literate

Main command line for starphleet, this is the program you use on *your computer*
to control and provision a phleet, contrast this with the starphleet-\* commands
which are run on shipts in a phleet.

    {docopt} = require 'docopt'
    fs = require 'fs'
    path = require 'path'
    _ = require 'lodash'
    handlebars = require 'handlebars'
    async = require 'async'
    md5 = require 'MD5'
    AWS = require 'aws-sdk'
    pkg = require(path.join(__dirname, "../package.json"))
    colors = require 'colors'
    doc = """
    #{pkg.description}

    Usage:
      starphleet init <headquarters_url> <public_key_filename>
      starphleet info
      starphleet add ship <zone>
      starphleet remove ship <name>
      starphleet rolling reboot
      starphleet -h | --help | --version

    Notes:
      This uses the AWS API, so you will need these environment variables set:
        * AWS_ACCESS_KEY_ID
        * AWS_SECRET_ACCESS_KEY
      In addition AWS_DEFAULT_REGION will be consulted, and if not set, will
      default to us-west-1

    Description:
      This tool uses the AWS API for you to create a properly provisioned phleet
      including:
        * Setting up security policies
        * Setting up multiple container ships, which are hosts with a cute name
        * Setting up load balancing across ships for the whole phleet
        * Spreading your phleet across availability zones

      init
        This takes an URL and a public key in a file. The URL points to your
        headquarters, and you need to be able to get at this without a login, so
        just give it your public git URL of your headquarters. The public key
        will be used for the 'ubuntu' account you can use to ssh directly to
        each ship in the phleet. This is a big feature over other PaaS, you can
        actually get at 'the machine'.

        You can fork https://github.com/wballard/starphleet.headquarters.git to
        start up a headquarters and save starting from scratch.

      info
        This will show you:
          * all about the load balancing across the ships
          * all the container ships in your phleet

      add ship
        Add a ship in a specific availability zone.

      remove ship
        Remove a ship by name, which you can get from 'info'.

      rolling reboot
        When something is wrong, and you can't figure it out, and you just want
        to start over, call this, and each ship in the phleet will be rebooted
        in sequence. It might not fix anything, but nothing feels as good as
        'reboot it!'.

    """
    options = docopt doc, version: pkg.version
    zones = _.map [
      'us-east-1',
      'us-west-1',
      'us-west-2',
      'eu-west-1',
      'sa-east-1',
      'ap-northeast-1',
      'ap-southeast-1',
      'ap-southeast-2'
    ], (x) -> new AWS.EC2 {region: x, maxRetries: 15}
    zones = _.map zones, (zone) ->
      zone.elb = new AWS.ELB {region: zone.config.region, maxRetries: 15}
      zone
    zones = _.first(zones, 4)

    isThereBadNews = (err) ->
      if err
        console.error "#{err}".red
        process.exit 1

Init is all about setting up a .starphleet file with the key and url. This will
be used by subsequent commands when creating ships.

    if options.init
      config =
        url: options['<headquarters_url>']
        public_key: new Buffer(fs.readFileSync(options['<public_key_filename>'], 'utf8')).toString('base64')
        keyname: "starphleet-#{md5(new Buffer(fs.readFileSync(options['<public_key_filename>'], 'utf8')).toString('base64')).substr(0,8)}"
        hashname: "starphleet-#{md5(options['<headquarters_url>']).substr(0,8)}"
      fs.writeFileSync '.starphleet', JSON.stringify(config)
      initZone = (zone, callback) ->
        async.waterfall [
          #checking if we already have the key
          (nestedCallback) -> zone.describeKeyPairs({}, nestedCallback),
          #adding if we lack the key
          (keyFob, nestedCallback) ->
            if _.some(keyFob.KeyPairs, (x) -> x.KeyName is config.keyname)
              nestedCallback()
            else
              zone.importKeyPair({KeyName: config.keyname, PublicKeyMaterial: config.public_key}, nestedCallback)
          #check for an existing ELB
          (nestedCallback) ->
            zone.elb.describeLoadBalancers({}, nestedCallback)
          #build an ELB if we need it
          (balancers, nestedCallback) ->
            if _.some(balancers.LoadBalancerDescriptions, (x) -> x.LoadBalancerName is config.hashname)
              nestedCallback()
            else
              zone.describeAvailabilityZones {}, (err, zones) ->
                isThereBadNews err
                zone.elb.createLoadBalancer
                  LoadBalancerName: config.hashname
                  Listeners: [
                    #on purpose TCP to do web sockets
                    Protocol: 'TCP'
                    LoadBalancerPort: 80
                    InstancePort: 80
                  ]
                  AvailabilityZones: _.map zones.AvailabilityZones, (x) -> x.ZoneName
                , nestedCallback
          #check for the starphleet security group
          (nestedCallback) ->
            zone.describeSecurityGroups {}, nestedCallback
          #and make the security group if needed
          (groups, nestedCallback) ->
            if _.some(groups.SecurityGroups, (x) -> x.GroupName is 'starphleet')
              nestedCallback()
            else
              zone.createSecurityGroup {GroupName: 'starphleet', Description: 'Created by Starphleet'}, nestedCallback
          #hook up all the ports into the security group
          (nestedCallback) ->
            zone.describeSecurityGroups {GroupNames: ['starphleet']}, (err, groups) ->
              isThereBadNews err
              allowed_ports = [22, 80, 443]
              grantIfNeeded = (port, grantCallback) ->
                if _.some(groups.SecurityGroups[0].IpPermissions, (x) -> (x.FromPort is port and x.ToPort is port))
                  grantCallback()
                else
                  grant =
                    GroupName: 'starphleet'
                    IpPermissions: [
                      IpProtocol: 'tcp'
                      FromPort: port
                      ToPort: port
                      IpRanges: [{CidrIp: '0.0.0.0/0'}]
                    ]
                  zone.authorizeSecurityGroupIngress grant, grantCallback
              async.each allowed_ports, grantIfNeeded, (err) ->
                isThereBadNews err
                nestedCallback()

        ], (err, results) ->
          isThereBadNews err
          callback()

      async.each zones, initZone, (err) ->
        isThereBadNews err
        process.exit 0

