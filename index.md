# Starphleet

**Repositories + Buildpacks + Containers = Autodeploy Services**

___

Starphleet is a toolkit for turning [virtual](http://aws.amazon.com/ec2/) or physical machine infrastructure into a continuous deployment stack, running multiple Git-backed services on one more nodes via [Linux containers](https://linuxcontainers.org/).

Starphleet borrows heavily from the concepts of the [Twelve-Factor App](http://12factor.net), and uses an approach that avoids many of the problems inherent in existing autodeployment solutions:

* Conventional virtualization, with multiple operating systems running on shared
  physical hardware, wastes resources, specifically RAM and CPU.  This costs real money.
* Autodeploy PaaS has the same vendor lock-in risks of old proprietary software.
* Continuous deployment is almost always a custom scripting exercise.
* Multiple machine / clustered deployment is extra work.
* Making many small services is more work than making megalith services.
* Deployment systems all seem to be at the *system* not *service* level.
* Every available autodeploy system requires that you set up servers to
  deploy your servers, which themselves aren't autodeployed.

# Overview
A few definitions and concepts so that the rest of the documentation makes
more sense.

* **Orders**: The atomic unit of Starphleet.  An individual Ruby, Python, NodeJS, or plain HTML **service** run in a [Linux container](https://linuxcontainers.org/).

* **Ship**: A virtual machine instance with one or more running orders.  Launched manually with `$ vagrant up` or the [Starphleet CLI](https://github.com/wballard/starphleet-cli).

* **Phleet**: A collection of one or more ships.  Phleets are intended to correspond to a single load-and-geo-balanced resource, such as `services.example.com`.

* **Git Repositories**: Starphleet requires the use of the following types of repositories.

  * **Starphleet**: Hosted by us and accessed at `github.com/wballard/starphleet.git`, contains the source code for Starphleet allowing you to bootstrap your headquarters repository.
  * **Headquarters**: Hosted by you at `{headquarters_git_url}` (with an example  [available](https://github.com/wballard/starphleet.headquarters.git) from us), contains the configuration for the ships (virtual machine instances) and associated [Linux containers](https://linuxcontainers.org/).  You will need one headquarters repository per phleet.
  * **Services**: Hosted by you at `{service_git_url}` and referenced in your headquarter's **orders** files, contains the source code for the individual services which run in [Linux containers](https://linuxcontainers.org/) on ships.

* **Environment Variables**: Starphleet is configured entirely by environmental variables, saving you the chore of repeatedly typing the same text.

# Get Started

1.  Clone the Starphleet repository to your workstation, then change your current directory to the cloned folder.

  ```bash
  $ git clone https://github.com/wballard/starphleet.git
  $ cd starphleet
  ```

1.  Set the environment variable for the Git URL to your Starphleet headquarters, which contain the configuration for your phleet.  We suggest you start by forking our [base headquarters](https://github.com/wballard/starphleet.headquarters.git).  Your headquarters Git URL **must be network reachable** from your hosting cloud, making [public git hosting services](https://github.com/) a natural fit for Starphleet.

  ```bash
  $ export STARPHLEET_HEADQUARTERS={headquarters_git_url}
  ```

1.  Set the environment variable for the locations of your public and private key files which are associated with the Git repository for your Starphleet headquarters.  If you have not yet generated these files, you can do so using [ssh-keygen](https://help.github.com/articles/generating-ssh-keys).  

  ```bash
  $ export STARPHLEET_PRIVATE_KEY=~/.ssh/{private_keyfile}
  $ export STARPHLEET_PUBLIC_KEY=~/.ssh/{public_keyfile}
  ```

After completing the above configuration steps, you can choose to deploy Starphleet (a) on your local workstation using [Vagrant](http://www.vagrantup.com), or (b) into the cloud with [Amazon Web Services (AWS)](http://aws.amazon.com).

## Locally (Vagrant)

[Vagrant](http://www.vagrantup.com) is a handy way to get a working autodeployment system inside a virtual machine right on your local workstation. Prebuilt base images are provided in the `Vagrantfile` for VMWare, VirtualBox and Parallels. The [Vagrant](http://www.vagrantup.com) option is great for figuring if your services will start/run/autodeploy without worrying about cloud configuration.

1.  From the cloned [Starphleet](https://github.com/wballard/starphleet) directory, `vagrant up` command, which will launch a new ship (virtual machine instance), get your `${STARPHLEET_HEADQUARTERS}`, deploy [Linux containers](https://linuxcontainers.org/) for each service, and configure an HTTP proxy for the ship, allowing access to each service.

  ```bash
  $ vagrant up
  ```

1.  Get the IP address, `{ship_ip}`, of your new virtual machine instance.

  ```bash
  $ vagrant ssh -c "ifconfig eth0 | grep 'inet addr'"
  ```
1.  Navigate in your web browser to `http://{ship_ip}/echo/hello_world`.  There will be an availability delay while Starphleet runs bootstrap code, however subsequent service deployments and updates will complete quickly.

## In the Cloud (AWS)

Starphleet includes [Amazon Web Services (AWS)](http://aws.amazon.com) support out of the box.  To initialize your phleet, you need to have an AWS account.

1.  Provision an Ubuntu EC2 Instance (Currently 14.04)

1.  Login to your provisioned instance

1.  Run the following command:

  ```bash
  $ sudo bash -c "$(curl -s https://raw.githubusercontent.com/wballard/starphleet/master/webinstall)"
  ```

## All Running?
Once you are up and running, look in your `${STARPHLEET_HEADQUARTERS}` repository at `echo/orders`. The contents of the orders directory are all that is required to get a web service automatically deploying on a ship (virtualized machine instance).

* `export PORT=3000` to know on what port your service runs.  This port is mapped, by Starphleet, back to `http://{ship_ip}/echo` (on port 80).
* `autodeploy https://github.com/wballard/echo.git` to know what to deploy.  Starphleet will automatically deploy your Ruby, Python, NodeJS, and static NGNIX projects with buildpacks.

Order-ing up your own service is just as easy as adding a new directory and creating the `orders` file. Add. Commit. Push. Magic, your service will be available.  Any time that a Git repository referenced in an orders file is updated, for example `github.com/wballard/echo.git`, it will be autodeployed to every ship watching your headquarters.

# How Do I?
Lots of reference later in the documentation, but this is where you go to get things done.

## Work on a Ship
Much different than other PaaS, Starphleet treats you like an adult. So, you can
easily get and grant ssh access.

* Multiple users can log in and control the fleet, they are called **admirals**.
* Configure SSH access by placing public key files in `${STARPHLEET_HEADQUARTERS}/authorized_keys`
* Access a ship with

  ```bash
  $ ssh admiral@ship
  ```

* Revoke access by deleting public key files in `${STARPHLEET_HEADQUARTERS}/authorized_keys`

## See What's Up
Once you have an ssh public key in `${STARPHLEET_HEADQUARTERS}/authorized_keys`, you can:

```bash
$ ssh admiral@ship starphleet-status
```

This gives you a quick snapshot of what is happening.

And, to look into a running service:

```bash
$ ssh admiral@ship tail -f  /var/log/syslog | grep ${SERVICE_NAME}
```

## Customize a Container
You can do anything you like to a container with simple shell scripting by creating a
`on_containerize` script right next to your `orders`. This will be run right before the buildpacks,
so it is a great place to toss on additional packages or make directories you need.

  ```bash
  #!/usr/bin/env bash
  #a sample script that is run when a container is built
  apt-get install -y freetds-dev libmysqlclient-dev
  ```

You can also make an `after_containerize` script that well, runs right after a
container is made, but right before your container starts as a service.


## Launch a new NodeJS Service
Given that you have a program that listens for HTTP/HTTPS traffic, setting it up has a few things to know.

* Make sure your `npm install` works, most likely mistake is you have global packages on your workstations.
* Make sure your `npm start` works, the most likely mistake is you don't honor the `${PORT}` variable.
* Create a new directory in your headquarters, and within that make an `orders` file.

  ```bash
  $ mkdir myservice
  $ touch myservice/orders
  ```

* Configure your orders with an editor. This is a sample service.

  ```bash
  autodeploy https://github.com/wballard/echo
  ```

* Check that things are running

  ```bash
  $ ssh admiral@ship starphleet-status
  ```

## Make a Service with no Service
Huh? So the idea is you can publish just raw shell scripts, no need for
a buildpack to run at all.

Make orders that just look like this:

```bash
unpublished
```

Then, in your orders directory, you can load up on `#@` scripts.

## See Why a Service Failed To Start
Services have build logs and run logs. Run logs are in syslog, but build logs
can be had with.

* Configure SSH access by placing your public key file in `${STARPHLEET_HEADQUARTERS}/authorized_keys`
* View and tail build logs

  ```bash
  $ ssh admiral@ship starphleet-logs ${SERVICE_NAME}
  ```

## Debug a Service
Services log -- and you must log to `stderr` and `stdout`. With that, your running
service will forward to syslog on each ship.

* Configure SSH access by placing your public key file in `${STARPHLEET_HEADQUARTERS}/authorized_keys`

* Tail syslog, grepping for your `${SERVICE_NAME}`

  ```bash
  $ ssh admiral@ship tail -f /var/log/syslog | grep ${SERVICE_NAME}
  ```

## Reference Other Data Files
If your service needs data files, for example templates, you can deploy them as shared data as a **remote**.
This synchronizes a git repository to your ship that isn't a **service**, it is just **data**.

* In your headquarters make a folder called '${name}'
* In that folder, make a file called `remote`
  * Place `autodeploy ${your_git_url}` in that file
* Your data will be available at `/var/data/${name}` inside your containers

## Authenticate with LDAP
Starphleet can talk to your LDAP servers, authenticating on a per service basis. Set it up:

* Make sure your headquarters has a `/ldap_servers` folder
* Make a file in that folder, here is our example `guardian`
  ```bash
  export LDAP_URL='ldap://guardian-gc.glgresearch.com:3268/dc=glgroup,dc=com?sAMAccountName?sub?(objectCategory=person)(objectClass=User)'
  export LDAP_USER='glgroup\\sampleServiceAccount'
  export LDAP_PASSWORD='****'
  ```
* Now you have a named LDAP server
* In your service, make a file `/${service_name}/.ldap`
* In that file, pase the name of the LDAP server, in this case
  ```bash
  guardian
  ```

## Health Check my Service
Orders service repository can supply a `{HEALTHCHECK}` like:

```bash
export HEALTHCHECK='/'
```

Upon deployment of a service update, Starphleet will issue a GET request to `http://{container_ip}:{PORT}/{HEALTHCHECK}`, and will expect an HTTP 200 response within 60 seconds.
The `{PORT}` in the preceding URL will have the value specified in your orders.

If you fail the check, the service doesn't deploy.

## Talk to Other Services
On the same ship, all services are published and can be reached at `http://localship/${service}/`. Just plug in your `${service}`, the name `localship` will refer to the ship, while `localhost` refers to the service container.

## Schedule a Task
Starphleet lets you specific `#@` directives in shell scripts in order to schedule
jobs in a container. These with in containers with services, so the most common
thing you do is curl yourself:

```bash
#!/usr/bin/env bash
#@ * * * * 1

#This is a simple sh-at scheduled job example, it just hits the local
#service -- which is on the container itself and so isn't at /echo
curl http://localhost/on_container

#and you can always hit the ship, in which case you need to use the service
#url /echo
curl http://localship/echo/on_ship

```

The `#@` directive is just a cron scheduling expression captured inside the
script itself.

## Make a MicroService Cloud
The primary idea of Starphleet is to let you quickly create a cloud of related microservice. To make this easier, the key abstraction is that your services are at **paths** not **ports** by default. This lets you order up a series of services and have them all on one DNS name, saving you a lot of heartache with CORS, load balancers, and DNS configuration.

Say you have a simple service with a todo list, a mail queue, and a website. You can set up a headquarters like:

```
./orders
./todo
  orders
./mail
  orders
```

Then when running you get your site at `http://example.co/`, and your services at `http://example.co/todo` and `http://example.co/mail`.

## Set up Multiversion Betas
You can run more than one version of your service, and route users along to a different version based on their logged in HTTP identity.

This requires LDAP or HTTP basic, or an optional cookie that your app will set. Inside the cookie, or auth header, the username drives the beta behavior.

Set up a beta group in the headquarters repository in `beta_groups/`. This is just a text file, with one user identity per line.


### /beta_groups/stones
```
fred
wilma
```

### /beta_groups/sharks
```
white
hammerhead
```

Order your service twice, say at a branch

### /sample
```
autodeploy http://github.com/you/sample
beta stones /sample_beta
beta sharks /sample_shark_beta
```

### /sample_beta
```
autodeploy http://github.com/you/sample#beta
```

### /sample_shark_beta
```
autodeploy http://github.com/you/sample#shark
```

OK -- so the service is there at three urls at threr branches. Beta users will
go to the appropriate 'other' location with a server side rewrite. Cool!

# Reference


## Headquarters
A headquarters is a Git repository that instructs the phleet (one or more virtual machine instances) how to operate. Using Git in this manner

* Provides a versioned database of your configuration
* Allows editing and working with your own tools
* Provides multiple hosting options
* Avoids the need for a separate Starphleet server

By default, all services are federated together behind one host name. This is particularly useful for single page applications making use of a set of small, sharp back end services, without all the fuss of CORS or other cross domain technique.  Note that the Git URL value assigned to `STARPHLEET_HEADQUARTERS` **must be network reachable** from each ship in the phleet.

### File Structure

The `STARPHLEET_HEADQUARTERS` repository is the primary location for phleet, ship, and service configuration, and can contain the following directories and files:

```
authorized_keys/
  user1@example.com.pub
  user2@example.com.pub
beta_groups/
  friends
ldap_servers/
  boss
{service_name}/
  .htpasswd
  .ldap
  orders
  remote
overlay/
shipscripts/
  dynamic_dns_example.sh
  maintenance_example.sh
ssl/
  crt
  key
.starphleet
```

#### authorized_keys/
A directory containing public key files, one key per file, which allows ssh access to the ships as follows:

```bash
$ ssh admiral@{ship_ip}
```

Every user shares the same username, `admiral`, which is a member of the sudoers group.  Once pushed to your headquarters, updates to the `authorized_keys/` directory will be reflected on your ships within seconds.  This open ssh access to each ship lets you do what you want, when you want.  If you manage to wreck a ship, you can always add a new one using the [Starphleet CLI](https://github.com/wballard/starphleet-cli).

#### beta_groups/
Working together with authentication, you can create **beta groups**. These groups provide a named list of users.

```
wballard
fred
```

#### ldap_servers/
Authenticate users to your services via LDAP by specifying LDAP servers. Each named file in this directory requires three environment variables to connect a service account for end user LDAP Authentication. Here is how we hook up to our active directory:

```bash
export LDAP_URL='ldap://guardian-gc.glgresearch.com:3268/dc=glgroup,dc=com?sAMAccountName?sub?(objectCategory=person)(objectClass=User)'
export LDAP_USER='glgroup\\sampleServiceAccount'
export LDAP_PASSWORD='****'
```

You can have multiple LDAP servers. Individual user authentication will be cached, so that services with the same `.ldap` value will not multiply prompt for login.

#### {service_name}/
A directory which defines the relative path from which your service is served (`echo/` in the case of the [base headquarters](https://github.com/wballard/starphleet.headquarters.git)) and which contains the service configuration files as its contents.  Starphleet will treat as a service any root directory in your headquarters which contains an orders file and which does not use a reserved name (which are the other folder names in this section).  It is also possible to launch a service on `/`, by including an `orders` file at the root of your Starphleet headquarters repository.

* **.htpasswd**: Similar to good old fashioned Apache setups, you can put an `.htpasswd` file in each order directory, right next to `orders`. This will automatically protect that service with HTTP basic, useful to limit access to an API.

  **.ldap**: Place a single string in here that matches a file name under `{headquarters}/ldap_servers`. This will require users to be authenticated against LDAP.

* **orders**:  An `orders` file is a shell script which controls the autodeployment of a service inside a [Linux container](https://linuxcontainers.org/) on a ship.

  We chose to use shell scripts for the orders files to allow your creativity to run wild without needing to learn another autodeployment tool.

  ```bash
  autodeploy {service_git_url}
  beta {beta_group} {service_url}
  stop-before-autodeploy
  ```

  You can specify your `{service_git_url}` like `{service_git_url}#{branch}`, where branch can be a branch, a tag, or a commit sha -- anything you can check out. This hashtag approach lets you specify a deployment branch, as well as pin services to specific versions when needed.  The service specified in the orders file with the `{service_git_url}` must support the following:
  1. Serve HTTP traffic to the port number specified in the `PORT` environment variable.  Websockets can also be utilized, it is just http after all.
  1. Be hosted in a Git repository, either publicly available or accessible via key-authenticated git+ssh.
  1. Able to be installed and run with a buildpack.

  The [Linux containers](https://linuxcontainers.org/) which run the services are thrown away on each new service deployment and on each ship reboot.  While local filesystem access is available with a container, it is not persistent and should not be relied upon for persistent data storage.  Note that your `0service_git_url}` **must be network reachable** from each ship in the phleet.

  The `beta` command references a `beta_group` by name, and will transparently send any user identified in the group to the alternate `service_url`. Users are identified vit `.htpasswd` or `.ldap`. The `service_url` is just another ordered service on the ship, most likely a different branch to test a new feature.

  The `stop-before-autodeploy` command is useful for services that are not rolling deployment friendly. For example, we have an index service we call `pi` that uses [SOLR](http://lucene.apache.org/solr/) that has a nasty habit of not retrying to get at locked files. So, this makes sure to stop first, releasing the file lock.

* **remote**: A file specifying data to be autodeployed to to `/var/data/{service_name}` inside the [Linux container](https://linuxcontainers.org/) for `service_name`.  Starphleet symlinks `/var/data/` for all [Linux containers](https://linuxcontainers.org/) to `/var/data/` on the parent ship.  As a result, data specified by the `remote` file is visible to all [Linux container](https://linuxcontainers.org/) instances on a ship.  Only one item is needed inside a `remote` file:

  ```bash
  autodeploy {data_git_url}
  ```

* **jobs**
  Any shell script that contains a `@#` cron directive, and is executable, will be scheduled
  to run in the container.

  All [Linux containers](https://linuxcontainers.org/) support `cron`, but the jobs file allows you to dodge a few common problems with cron:

  * The logging gets captured to syslog for you automatically and then piped to `logger`.
  * The environment is fixed inside your container for your service.
  * You don't need to think about which account runs the jobs.

Each ship in the phleet runs every ordered service. This makes things nice and symmetrical, and simplifies scaling. Just add more ships if you need more capacity. If you need full tilt performance, you can easily make a phleet with just one ordered service at `/`. Need a different mixture of services? Launch another phleet!

While each [Linux container](https://linuxcontainers.org/) (and by extension, service) has its own independent directory structure, Starphleet symlinks `/var/data/` in each [Linux container](https://linuxcontainers.org/)  to `/var/data/` on the ship, allowing

  1. Data that lives between autodeploys of your service
  1. Collaboration between services

As `/var/data/` is persistent across autodeploys, care must be taken to ensure the ship's storage does not become full.  Also, note that `/var/data/` is a shared **local** fileystem across [Linux containers](https://linuxcontainers.org/) on the same ship.  It does not provide a shared filesystem between ships in a phleet.

#### overlay/
This is a directory full of any files you see fit. Whenever the headquarters is updated, these files are recursively copied, as root from the the headquarters to `/` on your ship, such that a file at `{headquarters/overlay/hi_mom` ends up at `/hi_mom` on your running ship.

#### shipscripts/
A directory containing scripts, which will run on individual ships when the headquarters is updated.

Scripts in this folder can be used to implement many different kinds of functionality, including dynamic DNS registration.  If you want to simulate dynamic DNS with Amazon Route53, look at the [starphleet-cli](https://github.com/wballard/starphleet-cli) command `starphleet name ship ec2`.  Note that scripts in this directory **must be marked as [executable](http://www.dslreports.com/faq/linux/7.1_chmod_-_Make_a_file_executable)** in order to run on the ships.  Scripts also run as root on the ships - take care to avoid a shipwreck.

#### ssl/
Provide two files `crt` and `key`, which must be set to not need a password, in order to enable
the ship to service SSL.



#### .starphleet
A file which contains environment variables that apply to all services in your phleet.  This file is a good place to store usernames, passwords, and connection strings, if your headquarters is in a private, hidden repository reachable by `git+ssh`.  The environment variables set in this file take precedence over all others set elsewhere, and apply to every service deployment within a phleet.


## Environment Variables
Starphleet is configured entirely by environmental variables and encourages the use of custom environment variables.  Some environment variables may apply to certain levels (an individual service or a phleet) or may need to remain private for security reasons (login credentials), and as a result Starphleet will apply environment variables in the following order:

1. **`{service_git_url}/.env`**

  The environment variable file sourced from the root directory of your service (at the root of the `service_git_url` specified in your service `orders` file).  As services will typically be hosted publically, the environment variables added to a `.env` file should concern development mode or public settings, such as `BUILDPACK_URL`.  These variables have the lowest precedence and apply to all of this particular service's deployments, regardless of phleet.

2. **`{headquarters_git_url}/{service_name}/orders`**

  The shell script used to autodeploy your service. Environment variables commonly set here include `PORT`, and apply to all service instances spawned from your headquarters.  These variables have precedence over those set in your service's `.env` file and apply to all of the specified particular service's deployments within a phleet.

3. **`{headquarters_git_url}/.starphleet`**

  The environment variable file which applies to all services in your phleet.  This file is a good place to store usernames, passwords, and connection strings, if your headquarters is in a private, hidden repository reachable by `git+ssh`.  These variables have the highest precedence and apply to every service deployment within a phleet.

### Environment Variable Reference

#### For Your Workstation

| Name | Value | Description
| --- | --- | ---
| AWS_ACCESS_KEY_ID | string | Used for [AWS](http://aws.amazon.com) access.  Set this on your workstation prior to using Starphleet CLI.
| AWS_SECRET_ACCESS_KEY | string | Used for [AWS](http://aws.amazon.com) access.  Set this on your workstation prior to using Starphleet CLI.
| EC2_INSTANCE_SIZE | string | Override the size of EC2 instance with this variable.  Set this on your workstation prior to using Starphleet CLI.
| STARPHLEET_HEADQUARTERS | string | The Git repository URL to your phleet's headquarters.  Set this on your workstation prior to using Starphleet CLI.
| STARPHLEET_PRIVATE_KEY | string | The path to the private keyfile associated with your Git repository, such as `~/.ssh/{private_keyfile}`.  Set this on your workstation prior to using Starphleet CLI.
| STARPHLEET_PUBLIC_KEY | string | The path to the public keyfile associated with your Git repository, such as `~/.ssh/{public_keyfile}`.  Set this on your workstation prior to using Starphleet CLI.
| STARPHLEET_VAGRANT_MEMSIZE | number | The memory size, in megabytes, of the [Vagrant](http://www.vagrantup.com) instance.  Set this on your workstation prior to using Starphleet Vagrant for testing.

#### For Your Headquarters
These variables can be set in your headquarters `.starphleet` or `orders`.

| Name | Value | Description
| --- | --- | ---
| BUILDPACK_URL | git_url | Specifies a custom buildpack to be used for autodeployment.  Set this in your Starphleet headquarters or in your service Git repository.
| PORT | number | This is an **all important environment variable**, and it is expected your service will honor it, publishing traffic here. This `PORT` is used to know where to connect the ship's proxy to your individual service.
| STARPHLEET_PULSE | number | The number of seconds between autodeploy checks, defaulting to a value of 10.
| USER_IDENTITY_HEADER | string | When using LDAP or basic authentication, Starphleet will write the user identity into this header so that your services can see it.
| USER_IDENTITY_COOKIE | string | When using cookie based beta routing, Starphleet will look in this cookie for an identity string.


## Buildpacks
Buildpacks autodetect and provision services in containers for you.  We would like to give a huge thanks to Heroku for having open buildpacks, and to the open source community for making and extending them. The trick that makes the Starphleet orders file so simple is the use of buildpacks and platform package managers to install dynamic, service specific code, such as `rubygems` or `npm` and associated dependencies, that may vary with each push of your service.  Note that **Starphleet will only deploy one buildpack per Linux container** - for services which are written in multiple languages, custom buildpacks may be required.

Starphleet currently includes support for Ruby, Python, NodeJS, and NGINX static buildpacks. You can specify your own in your `orders` with `export BUILDPACK_URL=`.

### [Procfile](https://devcenter.heroku.com/articles/procfile)
Starphleet only supports `web` process types.

### [NodeJS](https://github.com/heroku/heroku-buildpack-nodejs.git)
You will need a proper, working `package.json`. The buildpack will call `npm install` and `npm start`, with the `PORT` environment variable set.

Been at this a while? You can check in your `node_modules` directory, and the buildpack will call `npm reinstall`. This can speed up deployment greatly.

### [Ruby](https://github.com/heroku/heroku-buildpack-ruby.git)
This will run `bundle install` and make use of your `Procfile`.

### [NGINX](https://github.com/wballard/nginx-buildpack.git)
This looks for a `nginx.conf.erb` template. The configuration will be rendered with all available environment variables.

### [Makefile](https://github.com/wballard/makefile-buildpack)
This is a handy old school way to run pretty much any kind of service you like.

This follows the classic formula, working on a Makefile in the root of your
service.

```bash
./configure
make
make install
make start
```

## Maintenance

### Service Start
There is no need in Starphleet to explicitly call `nodemon`, `forever`, or any other keep alive system with your services, Starphleet will fulfill your dependencies and start your service automatically.  In NodeJS projects, this means Starphleet will load the proper buildpack (NodeJS), resolve dependencies by issuing an `$ npm install` command, and then (absent a procfile, see below) start your service by issuing an `$ npm start` command.  In order to use the automatic start functionality, ensure that:

1.  You include functional [procfiles](https://devcenter.heroku.com/articles/procfile) in your service repository, or
2.  Your project can be built and run with package manager specific features, such as `npm start` and `npm install`.

### Service Updates
Just commit and push to the repository referenced in your orders file, `{service_git_url}`, which will result in a service autodeployment to every associated ship (even across phleets if a service is used in more than one phleet).  As new versions of services are updated, fresh containers are built and run in parallel to prior versions with a drainstop. As a result, in-process requests to existing services should not interrupted, with one caveat: database and storage systems maintained outside of Starphleet.  Many software components are developed in a database-heavy manner with no real notion of backward compatibility for data storage.  In order to unlock the full benefit of autodeployment and rolling upgrades in Starphleet, you must think about how different versions of your code will interact with your database and storage systems.

#### Healthcheck
E
### Service Rollbacks
If bad update goes out to a service, it can be easily reverted by using `$ git revert` to pull out the problem commits, then re-pushing to the `{service_git_url}` referenced in `{headquarters_git_url}/{service_name}/orders`.  This approach also preserves your commit and deploy history.

### Service Crashes
Starphleet monitors running services and will restart them on failure.

### Starphleet Updates
To check for the latest version of Starphleet on a ship and install an update, if needed, run the following:

```bash
$ ssh admiral@{ship} sudo starphleet_update
```

You will need to ensure your public key has been added to the `authorized_users/` directory in your Starphleet headquarters.

### Starphleet Status
You can always see what is going on with your ship using:

```bash
$ ssh admiral@{ship} starphleet-status
$ ssh admiral@{ship} starphleet-logs
```

### Self Healing Phleet
Each ship uses a pull strategy to keep up to date. This strategy has been chosen over push deployments for the following reasons:

* Ships go [up and down](http://en.wikipedia.org/wiki/Heavy-lift_ship#Submerging_types), and a pull-based strategy lets ships catch up easily if they are offline when a new version of a service is released.
* After a new ship is added to the phleet (`$ starphleet add ship`), the pull mechanism will catch it up automatically.
* The developer does not have to wait for a Heroku-style push completes, watching the build go by, and can instead move on to developing the next feature.


## Amazon Web Services

### EC2 Instance Sizes
Don't cheap out and go small. The default instance size in Starphleet is `m2.xlarge`, which is roughly the power of a decent laptop.  You can change this with by setting the `EC2_INSTANCE_SIZE` environment variable.

### Phleets
Don't feel limited to just one phleet. Part of making your own PaaS is to give you the freedom to mix and match services across phleets as you see fit.

# Development Mode

## What is Development Mode

When Starphleet is installed on your local machine through vagrant the behavior of starphleet changes in a way that facilitates local development.  Starphleet becomes your automated build-and-test environment.  Starphleet will manage the following tasks for you:

* Checking out all GIT repos and remote files associated with your headquarters
* Mapping the above mentioned repos to your machine
* Automated Container Deployment on file changes (saves) (optional)

Utilizing Starphleet as your build-and-test environment has the benefit of simplifying your workflow.  This also allows you to test your code changes against a real Starphleet environment that mimics your production systems.

## Configuring your environment

There are several ways you can configure the environment for a local Starphleet deployment:

* Export your variables manually
* Create an environment file and export your variables:  `${HOME}/.starphleet`
* Utilize web installation scripts (Examples can be found [here](https://github.com/glg/starphleet-dev-webinstalls))
* Run the appropriate deployment script (ex `vmware`) and answer the prompts

At a minimum you will need an un-password protected SSH key associated with your Git account for any private repositories associated with your Headquarters.  You will need the following environment variables:

```bash
STARPHLEET_HEADQUARTERS
STARPHLEET_PRIVATE_KEY
STARPHLEET_PUBLIC_KEY
```

You can read more about these variables [here](https://github.com/wballard/starphleet/blob/gh-pages/index.md#get-started)

## What is different between dev mode and production?

* Git repos associated with your orders are checked out to a different location
* Git repos are monitored for file changes rather than git commit changes for triggering deployments (optional)
* Starphleet 'always' tries to start a dead container.
* Starphleet uses date stamps instead of git hashes for container names
* Your working git directory is linked directly to containers

## Development Mode Special Directories

When you install Starphleet locally the ship will automatically grab git repositories associated with your orders and map them to a local directory for development.  This directory can be found here:

```bash
$ cd ${HOME}/starphleet_dev
```

Additionally, containers may use a special directory to persistently store data between deployments.  This directory inside your container is usually located in `/var/data`.  For your convenience you can find this directory locally on your machine here:

```bash
$ cd ${HOME}/starphleet_dev/data
```

## Unbinding your development directory from the container

The default behavior of Development mode links your working development directory all the way into the virtual containers.  This is ideal if your build system typically uses something like `gulp watch`.  You can run `gulp watch` and your changes will be realized immediately all the way inside the service container.  

In some instances this behavior may be unfavorable.  A few examples may be:

* Your service doesn't use a build system
* The build-pack for your service runs a 'rebuild' against your development directory and changes many files
* You experience stability issues with HGFS in vmware

In these instances you may wish to unbind your development directory from the container.  By adding a setting to your orders file you can change the behavior of Starphleet to instead detect changes as you save them in your development directory and run a full re-deploy of your containers automatically.  To trigger this behavior you can add the following to your 'orders' inside your [headquarters](https://github.com/wballard/starphleet/blob/gh-pages/index.md#headquarters).

```bash
DEVMODE_UNBIND_GIT_DIR=true
```

## Authentication

Some services depend on authentication.  Starphleet automatically supports LDAP and HTACCESS [authentication](https://github.com/wballard/starphleet/blob/gh-pages/index.md#service_name).  Services are written in such a way that they depend on HTTP headers that are provided by the authentication method.  If you need to simulate authenticated services in development mode you can add the following variable to your orders file:

```bash
DEVMODE_FORCE_AUTH=[username]
```

## Disabling Development Mode

There may be instances where you want to force starphleet to behave like a production environment locally on your machine.  In those instances you can simply touch a file to disable Development Mode:

```bash
$ touch /var/starphleet/live
```
