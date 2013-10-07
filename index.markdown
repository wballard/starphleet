---
layout: default
title: Starphleet Manual
---

<h1>Starphleet</h1>
<div class="well">
The fully open container based continuous deployment PaaS
</div>

This is a toolkit for turning virtual machine infrastructure into a
continuous deployment stack. Looking at what is out there, Starphleet
goes in a problem/solution format:

* Virtualization wastes resources, specifically RAM and CPU running
  multiple operating system images, which costs real money
  * containerization is the new virtualization, using LXC
  * storage-as-a-service gets you out of the DBA scaling game
* PaaS has the same vendor lock-in risks of old proprietary software,
  just without the computers
  * full open source is the only way to go
  * allow installation on public as well as private clouds
  * use machines as you see fit, say with large RAM, GPGPU, or special
    hardware
* Continous deployment is too hard, so folks default to batches and
  sprints
  * leverage git, allowing deployment with no more than the normal `git
    push` you use to share code
  * make continuous deployment the default
  * provides drainstop, restart, failover, and rollback as built ins
  * be like unix: files, scripts, environment variables -- and spare
    folks from the learning curve of yet another tool
* Dependencies suck up time
  * platform package managers, `npm`, `gem`, `apt` beat learning a new
    package/script system, and there is a ton of resource available via
    [Google]
  * Heroku Buildpacks already exist for most platforms, use them
  * Focus on building services, not on systems
* Multiple machine deployment is more work than running locally
  * Make load balancing the default, spanning computers and geographies
  * Make commands run across a phleet by default
* Making many small services should be easier than making big services
  * Easy deployment lowers the overhead of making many services
  * Allow multiple services to be mounted behing one HTTP endpoint and
    avoid cross domain and CORS hell
* Seeing what is going on across multiple machines is hard
  * aggregate all the logs for each container ship in the phleet, and for
    the entire phleet
  * provide simple dashboards that give you the basics without requiring
    understanding and installing other monitoring software

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

```
npm install starphleet
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
reachable by each ship running the starphleet software. In practice this
means your headquarters is published in a public `https` or passwordless
`git` protocol repository, not via `git+ssh`. All about open. If you
really need this to be private you have two good options:

* have your own private phleet and git behind your firewall
* `starphleet privatize <private_key_file>` equips the admiral --
  explained below with a private key to use via SSH

## Ship
Our cute name for a host computer or virtual machine, it goes with the
phleet metaphor. There are many ships in a fleet to provide scale and
geographic distribution.

## Container
An individual LXC container image running a service in a controlled
virtual environment.

## Service
An individual program, run in a container, on a ship, autodeployed
across a phleet. Services provide your application functionality over
HTTP, including the use of server sent events and websockets.

# Headquarters
A headquarters instructs a phleet what services to deploy and how to
serve it. A headquarters must be versioned with git, and hosted in a
location on the internet where each ship in the phleet can reach it.
The easiest thing to do is host on [github] or [bitbucket].

The simplest possible phleet has a directory structure like:

```
..
.
orders
```

Which will serve exactly one service at `/`. The path structure of the
headquarters create the virtual HTTP patch structure of your services,
specifically to let you have a set of services, implemented in different
technologies, to be federated together behind on domain name. This is
particularly useful for single page applications making use of a set of
small, sharp back end services.

As an example, imagine an application that has a front end, and two back
end web services `workflow` and `users`.

```
.
..
orders
workflow/
  .
  ..
  orders
users/
  .
  ..
  orders
```

## Orders
An `orders` file is simply a shell script run in the context of
starphleet, at a given path, to control the autodeployment of a service.
You can put anything in the script you like, it is just a shell script
after all, but in practice there are only two things to do:

* `export PORT`
* `autodeloy <git_url>`

Setting up orders as a shell script is to allow your creativity to run
wild, but without you needing to learn a custom tool, DSL, scriptin
language, config database, or API that seems to be the common approach.

### Security
**No Fooling Important**, `<git_url>`, just like your `<headquarters_url>`
needs to be publicly reachable from each ship in the fleet, or for you
to follow the instructions on privatization.

### Branches and Versions
You can specify your `<git_url>` like `<git_url>#<branch>`, where branch can
be a branch, a tag, or a commit sha -- anything you can check out. This
hashtag approach lets you specify a deployment branch, as well as pin
services to specific versions when needed.

## Buildpacks
Huge thanks to Heroku for having open buildpacks, and to the open source
community for making and extending them. The trick that makes the
starphleet orders file so simple is the use of buildpacks and platform
package managers to get your dependencies running.

### Provided Buildpacks
Using the available Heroku buildpacks, out of the box starphleet with
autodetect and provision a service running:

* Ruby
* NodeJS
* Java
* Play
* Python
* PHP
* Clojure
* Go
* Perl
* Scala
* Dart
* NGINX static
* Apache

### Custom Buildpacks
In the root of a service's repository, make a `.env`. This is just a
simple shell script that will be sourced. So, if you have a buildpack
you know you want to use with a service:

```.env
export BUILDPACK_URL=https://github.com/wballard/heroku-buildpack-nodejs.git
```

This buildpack is cloned and run to make a container from your service.

## Environments
Your app will need to talk to things, external web services,
storage-as-a-service, databases, you name it. Starphleet goes back to
basics and lets you set these through environment variables.

Some environment variables are just open config, and some environment
variables are really secrets, so starphleet provides multiple locations
where you can keep variables, with different security thoughts.

Environment variables are sourced as each service starts, meaning the
are read:

* when you deploy a new service
* when you autodeploy / upgrade a running service
* when a service crashes and self restarts

The environment variables are sourced in the order listed below, which
allows you to override.

### Services
Services themselves can have variables, these are inspired by Heroku,
and you keep them in the source repository of each service.

#### .env
This is where you specify a `BUILDPACK_URL`, but you can also put in
other variables as you see fit.

#### .profile.d/
You can mix in as many separate files here as you like, providing more
environment.

### Orders
The `orders` file itself is sourced for your service. This is where a
service learns about `PORT` and `AUTODEPLOY`.

### Starphleet
Starphleet wide environment variables are _secret_, supplied by
command line, not kept in git, and protected with public/private key
encryption.

```
starphleet set <name> <value>
```

This will contact each ship in the phleet, and provide it with the name
and value, encypted with the private key specified in `starphleet
init`. On each ship, right before a service starts, these set values are
decrypted with the paired public key and provide the _last override_,
the perfect place for production URLs, usernames, and passwords.

Since they are stored encrypted with your private key on each ship, only
those with the private key can set them.

## SSH Access
A big difference form other Paas: the ships are yours, and you can ssh
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

## Self Healing
Each ship uses a pull type strategy. This is different than other
platforms where you *push* your software to deploy. Some folks will not
like this, as it involves polling. Some folks think polling is evil.
Noted. Here are the reasons:

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

### healthcheck
Each service repository can supply a `healthcheck` file, which contains
an URL snippet `http://<container-ip>:<container-port>/<snippet>`. You
supply the `<snippet>`, and if you don't provide it, the default is just
blank, meaning hitting the root of your service.

As soon as a 200 comes back, you are good to go and the new service is
put into rotation to take over future requests from the prior version.

You get 60 seconds for your service to return this 200 past when it is
initially started.

# Services
Services are any program you can dream up that meet these conditions:

* Serve HTTP traffic to a PORT
* Are hosted in git
* Can read environment variables to get their settings
* Have a _buildpack_ to get dependencies

Unlike other PaaS which is trying to force you into a specific notion of
scalable programming, starphleet gives you more freedom.

* No specific scale up / scale out tradeoff is enforced
* No specific 'scaleable database' is mandated
* This is no specific API
* There are no mandated programming languages

## Autodeploy
This is really easy. Just commit and push to the repository referenced
in the orders. Every ship will get it.

## Rollback
Again, this is really easy, just use `git revert` and pull out commits,
then push to the repository referenced in the orders. Best thing is,
this preserves history.

# Ships
Each ship in the phleet runs every ordered service. This makes things
nice and symmetrical, and simplifies scaling. Just add more ships if you
need more capacity. If you need full tilt performance, you can easily
make a phleet with just one ordered service at `/`.

## Linux Versions
The actual ships are provided as virual machine images in EC2, VMWare,
and VirtualBox format. To keep things simple, these images are
standardized on a single Linux version. Some folks who have varying
preferences or notions about OS support contracts may not like this.
Noted. All of starphleet is open, feel free to port it over anywhere you
like. Some things to keep in mind:

* you will need LXC
* you will need Upstart
* buildpacks will need to work, which is easy with apt and work
  otherwise

In practice, packing things up as orders with buildpacks saves you from
OS-ing around ships.

## EC2 Instance Sizes
Please, don't cheap out and go to small. The recommended minimum size is an
m2.xlarge -- which is roughly the power of a decent laptop, so this is
the default.

# Phleets
Don't feel limited to just one phleet. Part of making your own PaaS is
to give you the freedom to mix and match as you see fit.

## Log Aggregation
Just nearly as painful as getting everything deployed -- keeping an eye
on it. You can generally get software that watches CPU, RAM, Disk,
Network interfaces -- and it basically tells you nothing about your
application. The real value is in logging, where you can have
specifics and details to hunt down trouble.

But, logs across multiple services, multiple machines, and multiple
geographies aren't exactly fun, so starphleet aggregates all logs from
all ships and containers for you. From there you can pipe this into
services like [splunk], or my personal favorite, tail it and grep it.

This also keeps you disks from filling up, since the logs are written to
a stream and not to disk.

## Geo Scaling AWS
By default, starphleet sets up four zones, three US, one Europe. Ships
are added explicitly to zones, and you aren't required to use them all.
It's OK for you to set up just in one location if you like. Or even have
a phleet with one ship.

### Route53 Configuration
