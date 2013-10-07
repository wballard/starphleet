#!/usr/bin/env coffee

###
Main command line for starphleet, this is the program you use on *your computer*
to control and provision a phleet, contrast this with the starphleet-\* commands
which are run on shipts in a phleet.
###

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
table = require 'cli-table'
request = require 'request'

doc = """
#{pkg.description}

Usage:
  starphleet init <headquarters_url> <private_key_filename> <public_key_filename>
  starphleet info
  starphleet add ship <region>
  starphleet remove ship <hostname>
  starphleet privatize <private_key_file>
  starphleet set <name> <value>
  starphleet -h | --help | --version

Notes:
  This uses the AWS API, so you will need these environment variables set:
    * AWS_ACCESS_KEY_ID
    * AWS_SECRET_ACCESS_KEY
  EC2_INSTANCE_SIZE will be consulted, defaulting to m2.xlarge

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
ami_name="starphleet-0.0.2"

isThereBadNews = (err) ->
  if err
    console.error "#{err}".red
    process.exit 1

for ev in  ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']
  if not process.env[ev]
    isThereBadNews "#{ev} needs to be in your environment".red

###
Slight twist on map, take an array mapping through a function, then
store the resulting mapped values back on the original array members by
extending them.
###
async.join = (array, mapper, propertyName, callback) ->
  async.map array, mapper, (err, mapped) ->
    if err
      callback(err)
    else
      callback undefined, _.map _.zip(array, mapped), (x) ->
        x[0][propertyName] = x[1]
        x[0]

###
Init is all about setting up a .starphleet file with the key and url. This will
be used by subsequent commands when creating ships.
###

if options.init
  key_content = fs.readFileSync(options['<public_key_filename>'], 'utf8')
  if key_content.indexOf('ssh-rsa') isnt 0
    isThereBadNews "The public key provided was not ssh-rsa"
  config =
    url: options['<headquarters_url>']
    public_key: new Buffer(fs.readFileSync(options['<public_key_filename>'], 'utf8')).toString('base64')
    private_key: new Buffer(fs.readFileSync(options['<public_key_filename>'], 'utf8')).toString('base64')
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
      #set a realistic LB health policy
      (optionalResult,nestedCallback) ->
        # If we generate a new load balancer, the optionalResult will contain information on that instance
        # Else we will be passed the callback as the first param
        if typeof optionalResult is 'function'
          nestedCallback = optionalResult

        zone.elb.configureHealthCheck
          LoadBalancerName: config.hashname
          HealthCheck:
            Target: 'TCP:80'
            Interval: 5
            Timeout: 2
            UnhealthyThreshold: 2
            HealthyThreshold: 2
          , nestedCallback
      #check for the starphleet security group
      (ignore, nestedCallback) ->
        zone.describeSecurityGroups {}, nestedCallback
      #and make the security group if needed
      (groups, nestedCallback) ->
        if _.some(groups.SecurityGroups, (x) -> x.GroupName is 'starphleet')
          nestedCallback undefined, groups
        else
          zone.createSecurityGroup {GroupName: 'starphleet', Description: 'Created by Starphleet'}, nestedCallback
      #hook up all the ports into the security group
      (ignore, nestedCallback) ->
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
      #and now -- we are all set up and ready to run, but there are
      #no instances started just yet
    ], (err, results) ->
      isThereBadNews err
      callback()

  async.each zones, initZone, (err) ->
    isThereBadNews err
    process.exit 0

if options.add and options.ship
  config = JSON.parse(fs.readFileSync '.starphleet', 'utf-8')
  zone = _.select(zones, (zone) -> zone.config.region is options['<region>'])[0]
  if not zone
    isThereBadNews "You must pick a region from #{_.map(zones, (x) -> x.config.region)}".red

  async.waterfall [
    (callback) ->
      zone.describeImages {Owners: ['925278656507'], Filters: [{Name:"name", Values:[ami_name]}]}, callback
    (images, callback) ->
      ami = images.Images[0].ImageId
      todo =
        ImageId: ami
        MinCount: 1
        MaxCount: 1
        KeyName: config.keyname
        SecurityGroups: ['starphleet']
        UserData: new Buffer(config.url).toString('base64')
        InstanceType:  process.env['EC2_INSTANCE_SIZE'] or 'm2.xlarge'
      zone.runInstances todo, callback
    (ran, callback) ->
      ids = _.map ran.Instances, (x) -> {InstanceId: x.InstanceId}
      zone.elb.registerInstancesWithLoadBalancer {LoadBalancerName: config.hashname, Instances: ids}, callback
  ], (err) ->
    isThereBadNews err
    process.exit 0

if options.info
  config = JSON.parse(fs.readFileSync '.starphleet', 'utf-8')
  UserData = new Buffer(config.url).toString('base64')
  queryZone = (zone, zoneCallback) ->
    async.waterfall [
      (callback) ->
        zone.elb.describeLoadBalancers {LoadBalancerNames: [config.hashname]}, callback
      (loadBalancers, callback) ->
        getInstances = (balancer, balancerCallback) ->
          instances = []
          for instance in balancer.Instances
            instances.push instance.InstanceId
          if instances.length
            zone.describeInstances {InstanceIds: instances}, balancerCallback
          else
            balancerCallback undefined, []
        async.join loadBalancers.LoadBalancerDescriptions, getInstances, 'Instances', callback
      (loadBalancers, callback) ->
        #just one, since we are getting it by name
        loadBalancers[0].Region = zone.config.region
        callback undefined, loadBalancers[0]
      #flattening away reservations as I don't care
      (balancer, callback) ->
        if balancer?.Instances?.Reservations
          instances = []
          for reservation in balancer.Instances.Reservations
            for instance in reservation.Instances
              if not instance.PublicDnsName
                instance.PublicDnsName = instance.State.Name
              instances.push instance
          balancer.Instances = instances
          callback undefined, balancer
        else
          balancer.Instances = []
          callback undefined, balancer
      #now poke at the instances via http to lean starphleet specifics
      (balancer, callback) ->
        baseStatus = (instance, callback) ->
          request {url: "http://#{instance.PublicDnsName}/starphleet/diagnostic", timeout: 2000}, (err, res, body) ->
            #eating errors
            callback undefined, body
        async.join balancer.Instances, baseStatus, 'BaseStatus', (err, instances) ->
          callback err, balancer
      #status relevant to starphleet, not raw EC2
      (balancer, callback) ->
        for instance in balancer.Instances
          if instance.BaseStatus
            instance.Status = 'ready'
          else if instance.State.Name is 'running'
            instance.Status = 'building'
          else
            instance.Status = 'offline'
        callback undefined, balancer
    ], zoneCallback

  async.map zones, queryZone, (err, all) ->
    isThereBadNews err
    if _.any(all, (balancer) -> balancer.Instances.length)
      for balancer in all
        if balancer.Instances.length
          hosts = new table
            head: ['Hostname', 'Status']
            colWidths: [60, 12]
          for instance in balancer.Instances
            hosts.push ["#{instance.PublicDnsName}", "#{instance.Status}"]
          lb = new table()
          lb.push Region: balancer.Region
          lb.push 'Load Balancer': balancer.DNSName
          lb.push 'Hosts': hosts.toString()
          console.log lb.toString()
    else
      console.log "do 'starphleet add ship [region]' to get started\nvalid regions #{_.map(zones, (x) -> x.config.region)}".yellow
    process.exit 0

if options.remove and options.ship
  queryZone = (zone, zoneCallback) ->
    async.waterfall [
      (callback) ->
        zone.describeInstances {Filters: [{Name:"dns-name", Values:[options['<hostname>']]}]}, callback
      (zoneInstances, callback) ->
        instance_ids = []
        for reservation in zoneInstances.Reservations
          for instance in reservation.Instances
            instance_ids.push instance.InstanceId
        callback undefined, instance_ids
      (instanceIds, callback) ->
        if instanceIds.length
          options.removing = true
          zone.terminateInstances {InstanceIds: instanceIds}, callback
        else
          callback()
    ], zoneCallback
  async.each zones, queryZone, (err) ->
    isThereBadNews err
    if not options.removing
      isThereBadNews "#{options['<hostname>']} not found"
    process.exit 0
