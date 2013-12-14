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
os = require 'os'

doc = """
#{pkg.description}

Usage:
  starphleet init ec2
  starphleet info ec2
  starphleet add ship ec2 <region>
  starphleet remove ship ec2 <hostname>
  starphleet name ship ec2 <zone_id> <domain_name> <address>...
  starphleet -h | --help | --version

Notes:
  This uses the AWS API, so you will need these environment variables set:
    * AWS_ACCESS_KEY_ID
    * AWS_SECRET_ACCESS_KEY
    * STARPHLEET_HEADQUARTERS
    * STARPHLEET_PUBLIC_KEY
    * STARPHLEET_PRIVATE_KEY
    * EC2_INSTANCE_SIZE will be consulted, defaulting to m2.xlarge

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

#All the exciting settings and globals
images =
  'us-west-1': 'ami-b698a9f3'
  'us-west-2': 'ami-2e12771e'
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
  if /LoadBalancerNotFound/.test("#{err}")
    console.error "No load balancer found for #{process.env['STARPHLEET_HEADQUARTERS']}".red
    console.error "Have you run".red
    console.error "  starphleet init ec2".blue
    process.exit 1
  else if err
    console.error "#{err}".red
    process.exit 1

mustBeSet = (name) ->
  if not process.env[name]
    console.error "#{name} needs to be in your environment".red
    process.exit 1

niceToHave = (name, message) ->
  if not process.env[name]
    console.error "#{name} #{message}".yellow

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
Naming for our LB which defines a cluster
###
hashname = ->
  url = process.env['STARPHLEET_HEADQUARTERS']
  "starphleet-#{md5(url).substr(0,8)}"

if options.ec2
  mustBeSet 'AWS_ACCESS_KEY_ID'
  mustBeSet 'AWS_SECRET_ACCESS_KEY'

###
Init is all about setting up a .starphleet file with the key and url. This will
be used by subsequent commands when creating ships.
###

if options.init and options.ec2
  mustBeSet 'STARPHLEET_HEADQUARTERS'
  initZone = (zone, callback) ->
    async.waterfall [
      #check for an existing ELB
      (nestedCallback) ->
        zone.elb.describeLoadBalancers({}, nestedCallback)
      #build an ELB if we need it
      (balancers, nestedCallback) ->
        if _.some(balancers.LoadBalancerDescriptions, (x) -> x.LoadBalancerName is hashname())
          nestedCallback()
        else
          zone.describeAvailabilityZones {}, (err, zones) ->
            isThereBadNews err
            zone.elb.createLoadBalancer
              LoadBalancerName: hashname()
              Listeners: [
                #on purpose TCP to do web sockets
                Protocol: 'TCP'
                LoadBalancerPort: 80
                InstancePort: 80
              ]
              AvailabilityZones: _.map zones.AvailabilityZones, (x) -> x.ZoneName
            , nestedCallback
      #set a realistic LB health policy
      (optionalResult, nestedCallback) ->
        # If we generate a new load balancer, the optionalResult will contain information on that instance
        # Else we will be passed the callback as the first param
        if typeof optionalResult is 'function'
          nestedCallback = optionalResult

        zone.elb.configureHealthCheck
          LoadBalancerName: hashname()
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

if options.add and options.ship and options.ec2
  mustBeSet 'STARPHLEET_HEADQUARTERS'
  mustBeSet 'STARPHLEET_PUBLIC_KEY', 'is not set, you will not be able to ssh ubuntu@host'
  niceToHave 'STARPHLEET_PRIVATE_KEY', 'is not set, you will only be able to access https git repos read only one way'
  url = process.env['STARPHLEET_HEADQUARTERS']
  zone = _.select(zones, (zone) -> zone.config.region is options['<region>'])[0]
  if not zone
    isThereBadNews "You must pick a region from #{_.map(zones, (x) -> x.config.region)}".red

  public_key_name = ''
  async.waterfall [
    #checking if we already have the key
    (nestedCallback) ->
      if process.env['STARPHLEET_PUBLIC_KEY']
        public_key_content =
          new Buffer(fs.readFileSync(process.env['STARPHLEET_PUBLIC_KEY'], 'utf8')).toString('base64')
        public_key_name = "starphleet-#{md5(public_key_content).substr(0,8)}"
        zone.describeKeyPairs {}, (err, keyFob) ->
          #adding if we lack the key
          if _.some(keyFob.KeyPairs, (x) -> x.KeyName is public_key_name)
            nestedCallback()
          else
            zone.importKeyPair {KeyName: public_key_name, PublicKeyMaterial: public_key_content}, ->
              nestedCallback()
      else
        nestedCallback()
    (callback) ->
      ami = images[options['<region>']]
      #leverage cloud-init cloud-config
      user_data =
        runcmd: [
          "apt-get install -y git",
          "mkdir /starphleet",
          "git clone https://github.com/wballard/starphleet.git /starphleet",
          "/starphleet/scripts/starphleet-install",
          "starphleet-headquarters #{process.env['STARPHLEET_HEADQUARTERS']}"
        ]
        write_files: [
          {
            content: fs.readFileSync(process.env['STARPHLEET_PRIVATE_KEY'], 'utf8') if process.env['STARPHLEET_PRIVATE_KEY']
            path: '/starphleet/private_keys/starphleet'
          },
          {
            content: fs.readFileSync(process.env['STARPHLEET_PUBLIC_KEY'], 'utf8') if process.env['STARPHLEET_PRIVATE_KEY']
            path: '/starphleet/public_keys/starphleet.pub'
          }
        ]
      todo =
        ImageId: ami
        MinCount: 1
        MaxCount: 1
        KeyName: public_key_name
        SecurityGroups: ['starphleet']
        UserData: new Buffer(JSON.stringify(user_data)).toString('base64')
        InstanceType:  process.env['EC2_INSTANCE_SIZE'] or 'm2.xlarge'
      zone.runInstances todo, callback
    (ran, callback) ->
      ids = _.map ran.Instances, (x) -> {InstanceId: x.InstanceId}
      zone.elb.registerInstancesWithLoadBalancer {LoadBalancerName: hashname(), Instances: ids}, callback
  ], (err) ->
    isThereBadNews err
    process.exit 0

if options.info and options.ec2
  mustBeSet 'STARPHLEET_HEADQUARTERS'
  queryZone = (zone, zoneCallback) ->
    async.waterfall [
      (callback) ->
        zone.elb.describeLoadBalancers {LoadBalancerNames: [hashname()]}, callback
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
          console.log "Dashboards are at", "http://<host>/starphleet/dashboard".cyan
          console.log "Remember to", "ssh ubuntu@<host>".cyan
    else
      console.log "do 'starphleet add ship ec2 [region]' to get started\nvalid regions #{_.map(zones, (x) -> x.config.region)}".yellow
    process.exit 0

if options.remove and options.ship and options.ec2
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

if options.name and options.ship and options.ec2
  route53 = new AWS.Route53 {region: 'us-east-1'}
  async.waterfall [
    #need to check for an existing record, shame there is no UPDATE...
    (nestedCallback) ->
      route53.listResourceRecordSets {HostedZoneId: options['<zone_id>'], StartRecordName: "#{os.hostname()}.#{options['<domain_name>']}", StartRecordType: 'A', MaxItems: '1'}, nestedCallback
    (records, nestedCallback) ->
      change =
        HostedZoneId: options['<zone_id>']
        ChangeBatch:
          Comment: 'Starphleet name update'
          Changes: []
      if records.ResourceRecordSets?[0]
        change.ChangeBatch.Changes.push
          Action: 'DELETE'
          ResourceRecordSet: records.ResourceRecordSets[0]
      change.ChangeBatch.Changes.push
        Action: 'CREATE'
        ResourceRecordSet:
          Name: "#{os.hostname()}.#{options['<domain_name>']}"
          Type: 'A'
          TTL: 300
          ResourceRecords: _.map options['<address>'], (x) -> Value: x
      route53.changeResourceRecordSets change, nestedCallback
  ], (err, results) ->
    isThereBadNews err
    console.log JSON.stringify results
    process.exit 0
