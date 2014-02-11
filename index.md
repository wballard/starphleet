<h1>Starphleet</h1>
<div class="jumbotron">
Containers + Buildpacks + Repositories = Autodeploy Services
</div>

This is a toolkit for turning virtual or physical machine infrastructure
into a continuous deployment stack. Here are some of the observed
problems in autodeployment:

* Virtualization wastes resources, specifically RAM and CPU running
  multiple operating system images, which costs real money
* Autodeploy PaaS has the same vendor lock-in risks of old proprietary software
* Continous deployment is almost always a custom scripting exercise
* Multiple machine / clustered deployment is extra work
* Making many small services is more work than making megalith services
* Seeing what is going on across multiple machines is hard
* Deployment system all seem to be at the *system* not *service* level
* Every available autodeploy system requires that you set up servers to
  deploy your servers, which themselves aren't autodeployed

# Get Started
You need a git repository that defines your **starphleet headquarters**,
you can start up by forking our [base
headquarters](https://github.com/wballard/starphleet.headquarters.git).

Keep track of where you fork it, you'll need that git url.
**Important**: the git url must be network reachable from your hosting
cloud, often the best thing to do is use public git hosting services.

I'm a big fan of environment variables, it saves typing repeated stuff.
Paste in your url from above into your shell like this:

```bash
export STARPHLEET_HEADQUARTERS=<git_url>
```

OK -- so that might not work for you, particularly if your
`STARPHLEET_HEADQUARTERS` was a git/ssh url. To make that work, you need
to have the private key file you use with github, something like mine:

```bash
export STARPHLEET_PRIVATE_KEY=~/.ssh/wballard@mailframe.net
```

And, you will want to be able to SSH to your ships, that's one of the
big benefits!

```bash
export STARPHLEET_PUBLIC_KEY=~/.ssh/wballard@mailframe.net.pub
```

Yeah, go ahead. Spam me, that's my real email :)

## Locally, Vagrant
Vagrant is a handy way to get a working autodeployment system right on
your laptop inside a virtual machine. Prebuilt base images are provided
in the `Vagrantfile` for both VMWare, VirtualBox and Parallels. Great
for figuring if your services will autodeploy/start/run without worrying
about load balancing.

```bash
git clone https://github.com/wballard/starphleet.git
cd starphleet
vagrant up
vagrant ssh -c "ifconfig eth0 | grep 'inet addr'"
```

Note the IP address from the last command, you can see the dashboard at
http://ip-address/starphleet/dashboard. This will take a few minutes the
first time.

Super magic is happening here pulling in the `STARPHLEET_HEADQUARTERS`
and `STARPHLEET_PRIVATE_KEY` specified before as environment variables.

If you would like to set the memory footprint of your ship you can run:
```bash
export STARPHLEET_VAGRANT_MEMSIZE=8192
```

## In the Cloud, AWS
Running on a cloud is ready to go with AWS. In order to get started, you
need to have an AWS account, and the environment variables:

```bash
#these are to appease AWS
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
#git url used to clone your headquarters
export STARPHLEET_HEADQUARTERS=git@github.com:wballard/starphleet.headquarters.git
#set a key path here if you have a private headquarters
export STARPHLEET_PRIVATE_KEY=~/.ssh/wballard@mailframe.net
#a public key that goes with your private key, use this to ssh to ships
export STARPHLEET_PUBLIC_KEY=~/.ssh/wballard@mailframe.net.pub
```

And, to get going

```bash
npm install -g starphleet-cli
starphleet --help

starphleet init ec2
starphleet add ship ec2 us-west-1
starphleet info ec2
```

This will take a bit to launch up the nodes, but note that once you have
em running, additional service deployments are going to be a lot quicker
as the virtual machines are already built. Way better than making new
VMs each time!

## All Running?
Once you are up and running, look in your forked headquarters at
`echo/orders`. This is all it takes to get a web service automatically
deploying:
* `export PORT=` to have a network port for your service
* `autodeploy git_url` to know what to deploy

Ordering up your own services is just as easy as adding a directory
where the service will mount, and plopping in an `orders` file. Add.
Commit. Push. Magic, any time that referenced git repo is updated, it
will be redeployed to every ship watching your headquarters.

# Concepts
The grand tour so you know what we are talking about with all of our
silly names.

## The 12-Factor App
Starphleet owes a lot to the [12 factor app](http://12factor.net). Learn
about it.

## Phleet
The top level grouping. You manage starphleet at this level. You can
make as many phleets as you like to arrange different groupings of
services.

Phleets are analagous to a single root URL, like
`http://services.myorg.com` would be one fleet, with multiple ships and
multiple services.

## Headquarters
A git repository that instructs a phleet how to operate. Using git in
this way gives a versioned database of your configuation, allows you to
edit and work with your own tools, and allows multiple hosting options.

Using git as the database avoids the need for a *starphleet server*.

### Security
**No Fooling Important** -- your `<headquarters_url>` git repo needs to be
reachable by each ship running the starphleet software.

The simple thing to do is use a public git repository via `https`. If you
really need a private repository, or security, you can specify a private
key and access git via `git+ssh`.

And, in the cases when you need it, you can host your phleet and
headquarters entierly inside your own firewall.

## Ship
Our cute name for a host computer or virtual machine, it goes with the
phleet metaphor. There are many ships in a fleet to provide scale and
geographic distribution.

## Orders
An individual program, run in a container, supported by a buildpack, on
a ship, autodeployed across a phleet. Services provide your application
functionality over HTTP, including the use of server sent events and
websockets.

# Phleets
Check the main [readme](https://github.com/wballard/starphleet). In
particular pay attention to the environment variables for public and
private keys.

# Headquarters
A headquarters instructs a phleet with orders to deploy and how to serve
them. A headquarters is a git repository, and hosted in a location on
the internet where each ship in the phleet can reach it. The easiest
thing to do is host on [github](http://www.github.com) or
[bitbucket](http://www.bitbucket.com).

## Mounting Services to URLs
The simplest possible phleet has a directory structure like:

```
authorized_keys/
containers/
.starphleet
orders
```

Which will serve exactly one service at `/` as specified by `orders`.
The path structure of the headquarters creates the virtual HTTP path
structure of your services.

By default, all services are federated together behind one host name. This is
particularly useful for single page applications making use of a set of
small, sharp back end services, without all the fuss of CORS or other
cross domain technique. *This may not be what you expect if you are used
to hooking up one hostname per service.* (And there is a hostname per service
override if needed)

As an example, imagine an application that has a front end, and three back
end web services: `/`, `/workflow`, and `/users`.

```
/
  orders
  workflow/
    orders
  users/
    orders
```

### .htpasswd
Similar to good old fashioned Apache setups, you can put an `.htpasswd`
file in each order directory, right next to `orders`. This will
automaticially protect that service with HTTP basic, useful to limit
access to an API.

### orders
An `orders` file is simply a shell script run in the context of
starphleet, at a given path, to control the autodeployment of a service.
You can put anything in the script you like, it is just a shell script
after all, but in practice there are only two things to do:

```bash
export PORT
autodeloy <git_url>
```

Setting up orders as a shell script is to allow your creativity to run
wild, but without you needing to learn a custom tool, DSL, scripting
language, config database, or API.

**No Fooling Important**, `autodeploy <git_url>`, just like your
`<headquarters_url>` needs to be reachable from each ship in the fleet.

You can specify your `<git_url>` like `<git_url>#<branch>`, where branch can
be a branch, a tag, or a commit sha -- anything you can check out. This
hashtag approach lets you specify a deployment branch, as well as pin
services to specific versions when needed.

### remote
Starphleet provides a shared data directory to each container at
`/var/data` inside the container. This is a mount back to the ship, and
is a perfect place to store shared data files.

And, this data can be autodeployed. You set this up with a folder tree
similar to mounting services, and in each directory, provide an `orders`
script. As an example:

```
/
  remote
  templates/
    remote
```

This will result in data looking like:

```
/var/data/
  ...synched files from remote
  templates/
    ...synched files from remote
```

Individal `remote` scripts are really just shell scripts with a special
`autodeploy` command:

```bash
autodeploy <git_url>
```

## authorized\_keys/
A big difference form other PaaS: the ships are yours, and you can `ssh`
to them. Specifically, you can put as many public keys in the
`authorized_keys` folder of your headquarters, one per file, to let in
other users as you see fit via ssh.

These special users are called `admirals`, again sticking with our
nautical theme.

Users get to a ship with `ssh admiral@ship`. The admiral account is a
member of `sudoers`.

In practice, this open access to the base machine lets you do what you
want, when you want, truly open. And if you use this power to somehow
destroy a ship -- somebody has to wreck the ship -- you can always just
add a new one.

And, even more fun -- the `authorized_keys` themselves are continuously
deployed, just add and remove admirals by adding and removing public key
files in your github repository. Updates in seconds.

## containers/
Given any shell script script in your headquarters named
`containers/name`, an LXC container `name` will be created on demand to
serve as a `STARPHLEET_BASE`. This works by first creating an LXC
container, then running your script on that container to set it up.

These custom build scripts are run as the ubuntu user inside the LXC
container that is itself a snapshot built on top of starphleet's own
base container.

## ships/
Ships, when configured with an appropriate git url and private key, will
push back their configuration here, one per ship. Individual ships are
identified by their hostname, which by default is built from their ssh
key fingerprint.

This ends up being a versioned database of your ships and where to find
them on the network -- handy!

## shipscripts/
Ships themselves may need a bit of configuration, so any script in this
directory that is executable will run when:

* Starphleet starts
* A change in IP address is detected

This is used to implement things such as dynamic DNS registration, in
fact you can look at `starphleet name ship ec2` in order to simulate
dynamic DNS with Amazon Route53.

In practice, you can put anything you like in here. Be aware they run as
root on the ship and you can easily destroy things.

# Environments
Your app will need to talk to things: external web services,
storage-as-a-service, databases, you name it. Starphleet goes back to
basics and lets you set these through environment variables.

Some environment variables are just config, and some environment
variables are really secrets, so starphleet provides multiple locations
where you can keep variables, with different security thoughts.

## Environment Variables
Name | Value | Description
--- | --- | ---
PORT | number | This is an all important environment variable, and it is expected your service will honor it, publishing traffic here. This `PORT` is used to know where to connect the ship's proxy to your individual service.
PUBLISH_PORT | number | Allows your service to be accessible on the ship at `http://<SHIP_DNS>:PUBLISH_PORT` in addition to `http://<SHIP_DNS/orders`.
STARPHLEET_BASE | name | Either a `name` matching `HQ/containers/name, or an URL to download a prebuilt container image. Defaults to the starphleet provided base container
STARPHLEET_REMOTE | &lt;git_url&gt; | Set this in your .starphleet to use your own fork of starphleet itself
STARPHLEET_PULSE | int | Default 5, number of seconds between autodeploy checks
BUILDPACK_URL | &lt;git_url&gt; | Set this when you want to use a custom buildpack
NPM_FLAGS | string | Starphleet uses a custom `npm` registry to just plain run faster, you can use your own here with `--registry <url>`
AWS_ACCESS_KEY_ID | string | Used for AWS access
AWS_SECRET_ACCESS_KEY | string | Used for AWS access
EC2_INSTANCE_SIZE | string | Override the size of EC2 instance with this variable
STARPHLEET_DEPLOY_TIME | date string | Set in your service environment to let you know when it was deployed
STARPHLEET_DEPLOY_GITURL | string | Set in your service environment to let you know where the code came from

## .env
Services themselves can have variables, these are inspired by Heroku,
and you keep them in the source repository of each service. These are
the variables with the lowest precedence.

Literally, make a `.env` file in the root of your service.

This is usually where you specify a `BUILDPACK_URL`, but you can also put in
other variables as you see fit.

Your services will often be hosted in public repositories, so the config
you put in here should be about development mode or public settings.

## orders
The `orders` file itself is sourced for your service. This is where a
service learns about `PORT` and `autodeploy`.

These settings are laid over the service, and provide the ability to set
variables for a service in the context of a single phleet, compared to
the service variables which are truly generic.

## .starphleet
Starphleet wide environment variables are applied last, leading to the
highest precedence. This is a great place to have your production
usernames, passwords, and connection strings.

Different than most systems, Starphleet sticks with the git/files
metaphor even for this configuration, rather than a command line to
set/get variables. All the benefits of source control and using your own
tools, and no additional server software is needed, making starphleet
simpler and less to break.

As an example:

```bash
#all services will see this domain name
export DOMAIN_NAME="production.com"
#every service is told to run at 3000 inside its container
export PORT=3000
```

Now, this is a file right in your headquarters. To keep these private
you put your headquarters in a private, hidden repository than can only
be reached by private key `git+ssh`.

If you are using vagrant, you can also place a .starphleet file in your
home directory (~/.starphleet), with global overrides,  allowing you to
use local environment variables that don't need to be checked into your
headquarters.

# Services
Services are any program you can dream up that meet these conditions:

* Serve HTTP traffic to a PORT
* Are hosted in git
* Install and run with a buildpack
* Can read environment variables to get their settings, especially
  `PORT`

Unlike other PaaS which is trying to force you into a specific notion of
scalable programming, starphleet gives you more freedom.

* No specific scale up / scale out tradeoff is enforced
* No specific 'scaleable database' is mandated
* This is no specific API
* There are no mandated programming languages

Services are run in LXC containers, and as such don't have acess to the
entire machine, LXC containers can be thought of
as a Linux environment without the kernel.

Containers are thrown away often, on each new version, and each server
reboot. So, while you do have local filesystem access inside a container
running a service, don't count on it living any lenght of time.

## Autodeploy
This is the most interesting feature, automatic upgrades, check the
[orders](#orders).

## Autorestart
No need to code in `nodemon` or `forever` or any other keep alive system in
your services, Starphleet will take care of it for you. Just run your
service with a simple command line using
[Procfile](https://devcenter.heroku.com/articles/procfile) or package manager
specific features like `npm start` and `npm install` scripts.

## Watchdog
And there is no need to *watch the watcher*, Starphleet monitors running
services and restarts them on failure.

## Healthcheck
Each service repository can supply a `healthcheck` file, which contains
an URL snippet **http://<container-ip>:<container-port>/<snippet>**. You
supply the `<snippet>`, and if you don't provide it, the default is just
blank, meaning hitting the root of your service.

As soon as a 200 comes back, you are good to go and the new service is
put into rotation to take over future requests from the prior version.

You get 60 seconds for your service to return this 200 past when it is
initially started.

## Containers
Starphleet encapsualtes each service in an LXC container. Starting from
a base container, you can create your own custom containers to speed up
builds as needed.

Containers serve to create fixed, cached sets of software such as compilers,
that don't vary with each push of your service.

### Provided Container
The
[starphleet-base](https://s3-us-west-2.amazonaws.com/starphleet/starphleet-base.tgz)
container is set up to run with buildpacks. It is built from a
[script](https://github.com/wballard/starphleet/blob/master/overlay/var/starphleet/containers/starphleet-base).

### Your Own Containers
There are two basic approaches:
* Save a container to a tarball reachable by URL
* Make a provision script and have each ship build

The tarball approach involves:
1. make an lxc container, however you see fit
2. use `starphleet-lxc-backup` to create a tarball of the container
3. publish the tarball wherever you can reach it via http[s]
4. use that published URL as `STARPHLEET_BASE`

The provision script approach involved:
1. make a script `name` in your headquarters `./containers/name`
2. use that `name` as `STARPHLEET_BASE`

### Caching
Containers will be cached, two sets of rules:
* script containers diff the script, so as you update the script the
  container will rebuild
* URL/tarball containers hash the URL, so you can old school cache bust
  by taking on ?xxx type verison numbers or #hash

### Shared Filesystem
Each container mounts `/var/data` back to the ship, which allows you a
place to save data that lives between autodeploys of your service. This
is a great place to leave files that you don't want to recreate each
time you push a new version.

This is also a way to use files to collaborate between services if you
like.

But beware -- depending on your ship's disk size, you can fill up your
disk and have all kinds of trouble if you abuse this. For example, if
you really want a service that has a database process inside -- great --
just make sure you have enough space to do it!

This is *not a distributed filesystem*, just a local filesystem.

## Buildpacks
Buildpacks autodetect and provision services on containers for you
without worrying about system or os level setup.

Huge thanks to Heroku for having open buildpacks, and to the open source
community for making and extending them. The trick that makes the
starphleet orders file so simple is the use of buildpacks and platform
package managers to get your dependencies running.

Buildpacks serve to install dynamic, service specific code such as `npm`
or `rubygems` that may vary with each push of your service.

### Provided Buildpacks
Using the available Heroku buildpacks, out of the box starphleet with
autodetect and provision a service running:

 | | | |
--- | --- | --- | ---
Ruby |  Python |  Node | NGINX static

### Testing Buildpacks
Sometimes you just want to see the build, or figure out what is going on.

Starphleet lets you directly push to a ship and run a service outside
the autodeploy process via a git push, think Heroku.

You will need to have a public key in the `authorized_keys` that is
matched up with a private key in your local ssh config. Remember, you
are pushing to the ship -- so this is just like pushing to any other git
server over ssh.

```bash
#the ship as a remote, the `name` can be anything you like
git remote add ship git@$SHIP_IP:name
#send along to the ship, this will build and serve
#printing out an URL where you can access it for test
git push ship master
#control C when you are bored or done
```

## WebSockets
Services can expose WebSockets as well as HTTP. Note: due to how
[socket.io](http://socket.io) client libraries work, it is only usable
mounted at `/`. Short explanation is that connection string it uses,
which it looks like an URL, just plain isn't -- it picks out the host
name and uses the *path* part as a namespace inside its messages rather
than as an actual HTTP path.

## Autodeploy
This is really easy. Just commit and push to the repository referenced
in the orders. Every ship will get it.

## Rollback
Again, this is really easy, just use `git revert` and pull out commits,
then push to the repository referenced in the orders. Best thing is,
this preserves history.

## Self Healing
Each ship uses a pull strategy to keep up to date. This is different
than other platforms where you *push* your software to deploy. Some
folks will not like this, as it involves polling. Some folks think
polling is evil. Noted. Here are the reasons:

* Ships go up and down, pull based lets ships catch up easily if they
  happened to be down when a new version was released
* Adding new ships is simple, just `starphleet add ship`, the pull
  mechanism catches it up automatically
* You don't have to personally sit through a Heroku style push, watching
  the build go by -- you can move on to the next feature

## Rolling Updates
As new versions of services are updated, fresh containers are built and
run in parallel to prior versions with a drainstop. This means in
process requests aren't interrupted like on other platforms.

OK -- so this is a bit idealistic. Lots of folks program in a database
heavy way with no real notion of backward compatibility. Getting the
full benefit of autodeployment and rolling upgrades requires you to
think about your storage, and how different versions of code may
interact with that. Or, totally ingore it -- you won't be any worse off
that with other autodeploy systems, or classic 'off the air' deployment.

# Ships
Each ship in the phleet runs every ordered service. This makes things
nice and symmetrical, and simplifies scaling. Just add more ships if you
need more capacity. If you need full tilt performance, you can easily
make a phleet with just one ordered service at `/`. Need a different
mixture of services? Launch another phleet!

## Updating Starphleet on a Ship
Starphleet provides ssh trigged maintenance commands, which allow the
`authorized_keys` specified admirals to perform maintenance. Assuming
you have a private key configured in your ssh, and there is a matching
public key in your headquarters, you can just:

```
ssh update@ship
```

Where *ship* is the ip or hostname of one of your ships. This will check
for the latest version of starphleet and install it for you. Cool!

## Linux Versions
The actual ships are provided as virual machine images in EC2, VMWare,
and VirtualBox format. To keep things simple, these images are
standardized on a single Linux version. Some folks who have varying
preferences or notions about OS support contracts may not like this.
Noted. All of starphleet is open, feel free to port it over anywhere you
like.

In practice, packing things up as orders with buildpacks saves you from
OS-ing around ships and just lets you focus on writing your services.
Think a bit like Heroku, where the version of the OS is a decision made
for you to save time.

## EC2 Instance Sizes
Please, don't cheap out and go to small. The recommended minimum size is an
m2.xlarge -- which is roughly the power of a decent laptop, so this is
the default. You can change this with `EC2_INSTANCE_SIZE`.

# Phleets
Don't feel limited to just one phleet. Part of making your own PaaS is
to give you the freedom to mix and match as you see fit.

## Log Aggregation
This is pretty cool `curl http://<ship>/starphleet/logstream`. This uses
[tailor](https://github.com/wballard/tailor) to provide a SSE stream of
log events.

Just nearly as painful as getting everything deployed -- keeping an eye
on it. You can generally get software that watches CPU, RAM, Disk,
Network interfaces -- and it basically tells you nothing about your
application. The real value is in logging, where you can have
specifics and details to hunt down trouble.

But, logs across multiple services, multiple machines, and multiple
geographies aren't exactly fun, so starphleet aggregates all logs from
all ships and containers for you. From there you can pipe this into
services like [splunk](http://www.splunk.com), or my personal favorite, tail it
and grep it.

This also keeps you disks from filling up, since the logs are written to
a stream and not to disk.

## Geo Scaling AWS
By default, starphleet sets up four zones, three US, one Europe. Ships
are added explicitly to zones, and you aren't required to use them all.
It's OK for you to set up just in one location if you like. Or even have
a phleet with one ship.

