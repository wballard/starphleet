<h1>Starphleet</h1>
<div class="jumbotron">
The fully open container based continuous deployment PaaS

Containers + Buildpacks + Repositories = Autodeploy Services
</div>



This is a toolkit for turning virtual or physical machine infrastructure
into a continuous deployment stack. Here are some of the observed
problems in autodeployment, and how Starphleet solves them:

* Virtualization wastes resources, specifically RAM and CPU running
  multiple operating system images, which costs real money
  * containerization is the new virtualization, using LXC
* PaaS has the same vendor lock-in risks of old proprietary software
  * full open source is the only way to go
  * allow installation on public and private clouds, as well as
    computers
* Continous deployment is too hard, so folks default to batches and
  sprints
  * leverage git, allowing deployment with no more than the normal `git
    push` you use to share code
  * make continuous deployment the default
  * provides drainstop, restart, failover, and rollback as built ins
  * be like unix: files, scripts, environment variables -- and spare
    folks from the learning curve of yet another system tool
  * platform package managers, `npm`, `gem`, `apt` beat learning a new
    package/script system, and there is a ton of resource available
  * Heroku Buildpacks already exist for most platforms, use them
  * Focus on building services, not on systems
* Multiple machine deployment is more work than running locally
  * Make load balancing the default, spanning computers and geographies
  * Make commands run across a phleet by default
* Making many small services is hard to deploy
  * Containerizing allows multiple services to benefit from failover and
    redundancy without burning two machines/VMs per service
  * Allow multiple services to be mounted behing one HTTP endpoint and
    avoid cross domain and CORS hell
* Seeing what is going on across multiple machines is hard
  * aggregate all the logs for each container ship in the phleet, and for
    the entire phleet
  * provide simple dashboards that give you the basics without requiring
    understanding and installing other monitoring software
* Autodeployment systems all seem to have their own system which itself
  needs to be deployed!
  * Starphleet leverages git heavily, avoiding the need for yet another
    database or daemon
  * Images are used as a starting point, avoiding the need to _install_
    the install software

# Concepts
The grand tour so you know what we are talking about with all of our
silly names.

## The 12-Factor App
Starphleet owes a lot to the [12 factor app](http://12factor.net). Learn
about it.

## Command Line
All of starphleet is available from a simple command line script, which
lets you hook it into any existing scripting framework you like without
needing to learn an API. The command line program is mostly shell, and
some nodejs, which is a nice way to deploy to your laptop or personal
computer to manage starphleet.

```bash
npm install "git+https://github.com/wballard/starphleet.git"
starphleet --help
```

## Phleet
The top level grouping. You manage starphleet at this level. You can
make as many phleets as you like to arrange different groupings.

## Headquarters
A git repository that instructs a phleet how to operate. Using git in
this way gives a versioned database of your configuation, allows you to
edit and work with your own tools, and allows multiple hosting options.

###Security
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
the internet where each ship in the phleet can reach it.  The easiest
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

The services are federated together behind one domain name. This is
particularly useful for single page applications making use of a set of
small, sharp back end services, without all the fuss of CORS or other
cross domain technique.

As an example, imagine an application that has a front end, and three back
end web services: `/`, `/workflow`, and `/users`.

```
orders
workflow/
  orders
users/
  orders
```

### authorized_keys/
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

### containers/
Given any shell script script in your headquarters named
`containers/name`, an LXC container `name` will be created on demand to
serve as a `STARPHLEET_BASE`.

These custom build scripts are run as virtual root in a dedicated LXC
container that is itself a snapshot built on top of starphleet's own
base container. Basically, this means you can use `apt-get` to easily
put on system software to serve as a base layer.

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

# Environments
Your app will need to talk to things: external web services,
storage-as-a-service, databases, you name it. Starphleet goes back to
basics and lets you set these through environment variables.

Some environment variables are just config, and some environment
variables are really secrets, so starphleet provides multiple locations
where you can keep variables, with different security thoughts.

The environment variables are sourced in the order listed below, which
allows you to override.

## Environment Variables

Name | Value | Description
--- | --- | ---
PORT | number | This is an all important environment variable, and it is expected your service will honor it, publishing traffic here. This `PORT` is used to know where to connect the ship's proxy to your individual service.
autodeploy | &lt;git_url&gt; | This command in orders tells starphleet where to grab code from git.  While it is possible to put this globally, you really should limit it just to `orders` files.
STARPHLEET_BASE | name | Either a `name` matching `HQ/containers/name, or an URL to download a prebuilt container image. Defaults to the starphleet provided base container
PUSH_HEADQUARTERS | any | When set, this will cause your headquarters to push back to the origin repository, allowing you to share state between ships.
STARPHLEET_REMOTE | &lt;git_url&gt; | Set this in your .starphleet to use your own fork of starphleet itself
STARPHLEET_PULSE | int | Default 5, number of seconds between autodeploy checks

## .env
Services themselves can have variables, these are inspired by Heroku,
and you keep them in the source repository of each service. These are
the variables with the lowest precedence.

This is where you specify a `BUILDPACK_URL`, but you can also put in
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

## healthcheck
Each service repository can supply a `healthcheck` file, which contains
an URL snippet **http://<container-ip>:<container-port>/<snippet>**. You
supply the `<snippet>`, and if you don't provide it, the default is just
blank, meaning hitting the root of your service.

As soon as a 200 comes back, you are good to go and the new service is
put into rotation to take over future requests from the prior version.

You get 60 seconds for your service to return this 200 past when it is
initially started.


# Services

Repository + Container + Buildpack = Service

Services are any program you can dream up that meet these conditions:

* Serve HTTP traffic to a PORT
* Are hosted in git
* Can read environment variables to get their settings, especially
  `PORT`

Unlike other PaaS which is trying to force you into a specific notion of
scalable programming, starphleet gives you more freedom.

* No specific scale up / scale out tradeoff is enforced
* No specific 'scaleable database' is mandated
* This is no specific API
* There are no mandated programming languages

Services are run in LXC containers, and as such don't have acess to the
entire machine, they are root in their own world of a container. This is
convenient, particularly when making custom buildpacks as you can just
use `apt-get install` without a sudo.

Containers are thrown away often, on each new version, and each server
reboot. So, while you do have local filesystem access inside a container
running a service, don't count on it living any lenght of time.

## Containers
Starphleet encapsualtes each service in an LXC container. Starting from
a base container , you can create your own custom containers to speed up
builds as needed.

Containers serve to create fixed, cached sets of software such as compilers,
that don't vary with each push of your service.

## Buildpacks
Buildpacks autodetect and provision services on containers for you
without worrying about system or os level setup.

Huge thanks to Heroku for having open buildpacks, and to the open source
community for making and extending them. The trick that makes the
starphleet orders file so simple is the use of buildpacks and platform
package managers to get your dependencies running.

Buildpacks serve to install dynamic, service specific code such as `npm`
or `rubygems` that may vary with each push of your service.

## Provided Buildpacks
Using the available Heroku buildpacks, out of the box starphleet with
autodetect and provision a service running:

 | | | |
--- | --- | --- | ---
Ruby |  NodeJS |  Java | Play
Python| PHP | Clojure | Go
Perl | Scala | Dart | NGINX static
Apache |||

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

