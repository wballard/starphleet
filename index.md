# Starphleet
**Repositories + Buildpacks + Containers = Autodeploy Services**

Starphleet is a toolkit for turning [virtual](http://aws.amazon.com/ec2/) or physical machine infrastructure into a continuous deployment stack, running multiple Git-backed services on one more more nodes via [OS-level virtualization](https://linuxcontainers.org/).  Starphleet borrows heavily from the concepts of the [Twelve-Factor App](http://12factor.net), and uses an approach that avoids many of the problems inherent in existing autodeployment solutions:

* Conventional virtualization, with multiple operating systems running on shared
  physical hardware, wastes resources, specifically RAM and CPU.  This costs real money.
* Autodeploy PaaS has the same vendor lock-in risks of old proprietary software
* Continous deployment is almost always a custom scripting exercise
* Multiple machine / clustered deployment is extra work
* Making many small services is more work than making megalith services
* Seeing what is going on across multiple machines is hard
* Deployment systems all seem to be at the *system* not *service* level
* Every available autodeploy system requires that you set up servers to
  deploy your servers, which themselves aren't autodeployed



# Overview

**Orders**: The atomic unit of Starphleet.  An individual Ruby, Python, NodeJS, or plain HTML **service** run in a [Linux container](https://linuxcontainers.org/).

**Ship**: A virtual machine instances with one or more running orders.

**Phleet**: A collection of one or more ships.  Phleets are intended to correspond to a single load-and-geo-balanced resource, such as `services.example.com`.

**Git Repositories**: Starphleet requires the use of the following types of repositories.

  * **Starphleet Core**: Hosted by us and accessed at `github.com/wballard/starphleet.git`, contains the source code for Starphleet allowing you to bootstrap your headquarters repository.  The Starphleet Core repository should exist in one location.
  * **Headquarters**: Hosted by you at `<headquarters_git_url>` (with an example  [available](https://github.com/wballard/starphleet.headquarters.git) from us), contains the configuration for the ships (virtual machine instances) and associated [Linux containers](https://linuxcontainers.org/).  You will need one headquarters repository per phleet.
  * **Services**: Hosted by you at `<service_git_url>` and referenced in your headquarter's **orders** files, contains the source code for your individual services.  Service repositories can be referenced by multiple orders files across phleets.

**Environment Variables**: Starphleet is configured entirely by environmental variables, saving you the chore of repeatedly typing the same text.

# Get Started

1.  Clone the Starphleet repository to your workstation, then change your current directory to the cloned folder.

  ```bash
  $ git clone https://github.com/wballard/starphleet.git
  $ cd starphleet
  ```

1.  Set the environment variable for the Git URL to your Starphleet headquarters, which contain the configuration for your phleet.  We suggest you start by forking our [base headquarters](https://github.com/wballard/starphleet.headquarters.git).  Your headquarters git URL **must be network reachable** from your hosting cloud, making [public git hosting services](https://github.com/) a natural fit for Starphleet.


  ```bash
  $ export STARPHLEET_HEADQUARTERS=<headquarters_git_url>
  ```

1.  Set the environment variable for the locations of your public and private key files which are associated with the git repository for your Starphleet headquarters.  If you have not yet generated these files, you can do so using [ssh-keygen](https://help.github.com/articles/generating-ssh-keys).  

  ```bash
  $ export STARPHLEET_PRIVATE_KEY=~/.ssh/<private_keyfile>
  $ export STARPHLEET_PUBLIC_KEY=~/.ssh/<public_keyfile>
  ```

After completing the above configuration steps, you can choose to deploy Starphleet (a) on your local workstation using **[Vagrant](http://www.vagrantup.com)**, or (b) into the cloud with **[Amazon Web Services (AWS)](http://aws.amazon.com)**.

## Locally (Vagrant)

[Vagrant](http://www.vagrantup.com) is a handy way to get a working autodeployment system inside a virtual machine right on your local workstation. Prebuilt base images are provided in the `Vagrantfile` for VMWare, VirtualBox and Parallels. The [Vagrant](http://www.vagrantup.com) option is great for figuring if your services will start/run/autodeploy without worrying about cloud configuration.

1.  From the cloned [Starphleet](https://github.com/wballard/starphleet) directory, us Vagrant's `up` command, which will launch a new ship (virtual machine instance), perform a git pull on your `STARPHLEET_HEADQUARTERS`, deploy a new [Linux container](https://linuxcontainers.org/), and configure the service specified in the Starphleet headquarters (including automatically running `$ npm install` and `$ npm start`).

  ```bash
  $ vagrant up
  ```

1.  Get the IP address, `<ship_ip>`, of your new virtual machine instance.

  ```bash
  $ vagrant ssh -c "ifconfig eth0 | grep 'inet addr'"
  ```
1.  Navigate in your web browser to `http://<ship_ip>/echo/hello_world`.  There will be an availability delay while Starphleet runs bootstrap code, however subsequent service deployments and updates will completely quickly.

## In the Cloud (AWS)
Starphleet includes [Amazon Web Services (AWS)](http://aws.amazon.com) support out of the box.  To initialize your phleet, you need to have an AWS account.

1.  Set additional environment variables required for AWS use.

  ```bash
  $ export AWS_ACCESS_KEY_ID=<your_aws_key_id>
  $ export AWS_SECRET_ACCESS_KEY=<your_aws_access_key>
  ```

1.  Install the Starphleet command line interface (CLI) tool

  ```bash
  $ npm install -g starphleet-cli
  ```

1.  Use the Starphleet CLI's `init` and `add` commands to launch a new ship (virtual machine instance), perform a git pull on your `STARPHLEET_HEADQUARTERS`, deploy a new [Linux container](https://linuxcontainers.org/), and configure the service specified in the Starphleet headquarters (including automatically running `$ npm install` and `$ npm start`).

  ```bash
  $ starphleet init ec2
  $ starphleet add ship ec2 us-west-1
  ```

1.  Get the IP address, `<ship_ip>`, of your new ship.

  ```bash
  $ starphleet info ec2
  ```

1.  Navigate in your web browser to `http://<ship_ip>/echo/hello_world`.  There will be an availability delay while Starphleet runs bootstrap code, however subsequent service deployments and updates will completely quickly.




## All Running?
Once you are up and running, look in your `<headquarters_git_url>` repository at `echo/orders`. The contents of the orders directory are all that is required to get a web service automatically deploying on a ship (virtualized machine instance).

* `export PORT=3000` to know on what port your service runs.  This port is mapped, by Starphleet, back to `http://<ship_ip>/echo` (on port 80).
* `autodeploy https://github.com/wballard/echo.git` to know what to deploy.  Starphleet will automatically deploy your Ruby, Python, NodeJS, and static NGNIX projects (see [buildpacks](#buildbpacks)).

Order-ing up your own service is just as easy as adding a new directory and creating the `orders` file. Add. Commit. Push. Magic, your service will be available.  Any time that a Git repository referenced in an orders file is updated, for example `github.com/wballard/echo.git`, it will be autodeployed to every ship watching your headquarters.



# Reference


## Headquarters
A headquarters is a Git repository that instructs the phleet (one or more virtual machine instances) how to operate. Using git in this manner

* Provides a versioned database of your configuation
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
containers/
  example_container.sh
<service_name>/
  .htpasswd
  orders
  remote
ships/
  ship-17bqr3zgg2d11ttcl133h2111p98qrt1
  ship-93ojdlkv9083lkd92klf90399fl39fjs
shipscripts/
  dynamic_dns_example.sh
  maintenance_example.sh
jobs
.starphleet
```

#### authorized\_keys/
A directory containing containing public key files, one key per file, which allows ssh access to the ships as follows: `ssh admiral@<ship_ip>`.  Every user shares the same username, `admiral`, which is a member of the sudoers group.  Once pushed to your headquarters, updates to the authorized\_keys/ directory will be reflected on your ships within seconds.  This open ssh access to each ship lets you do what you want, when you want.  If you manage to wreck a ship, you can always add a new one using the [Starphleet CLI](https://github.com/wballard/starphleet-cli).

#### containers/
A directory containing shell scripts to configure a custom [Linux container](https://linuxcontainers.org/) upon which your services will run.  These shell scripts are run as the `ubuntu` user inside the default Starphleet-provided base container, and serve to create fixed, cached sets of software such as compilers, that don't vary with each push of your service.  Note that to use one of these custom containers with your phleet, the `STARPHLEET_BASE` environment variable must be set to match `<starphleet_headquarters_uri>/containers/<container_name>.` Script containers diff the script, so as you update the script the container will rebuild.

Custom containers can also be stored and served outside your Starphleet headquarters repository, by saving a container to a tarball, and making this tarball reachable by URL.  Specifically, this alternate tarball approach involves:

1. Creating [Linux container](https://linuxcontainers.org/), however you see fit
1. Use `starphleet-lxc-backup` to create a tarball of the container
1. Publish the tarball to a URL reachable via http(s)
1. Use this published URL as `STARPHLEET_BASE`

URL/tarball containers hash the URL, so you can old school cache bust by taking on ?xxx type verison numbers or #hash.  The [starphleet-base](https://s3-us-west-2.amazonaws.com/starphleet/starphleet-base.tgz) container is set up to run with buildpacks, and the container itself is built from this [script](https://github.com/wballard/starphleet/blob/master/overlay/var/starphleet/containers/starphleet-base).

#### `<service_name>/`
A directory which defines the relative path from which your service is served (`echo/` in the case of the [base headquarters](https://github.com/wballard/starphleet.headquarters.git)) and which contains the service configuration files (.htpasswd and orders) as its contents.  Starphleet will treat as a service any root directory in your headquarters which contains an orders file and which does not use a reserved name (`authorized_keys`, `containers`, `remote`, `ships`, `ssl`, `.*`).  It is also possible to launch a service on `/`, by including an `orders` file at the root of your Starphleet headquarters repository.

* **.htpasswd**: Similar to good old fashioned Apache setups, you can put an `.htpasswd` file in each order directory, right next to `orders`. This will automatically protect that service with HTTP basic, useful to limit access to an API.

* **orders**:  An `orders` file is a shell script which controls the autodeployment of a service inside a [Linux container](https://linuxcontainers.org/) on a ship.

  We chose to use shell scripts for the orders files to allow your creativity to run wild without needing to learn another autodeployment tool, as they run in the context of Starphleet.  In practice, however, there are only two items normally present in an `orders` file:

  ```bash
  $ export PORT=<service_port>
  $ autodeploy <service_git_url>
  ```

  You can specify your `<service_git_url>` like `<service_git_url>#<branch>`, where branch can be a branch, a tag, or a commit sha -- anything you can check out. This hashtag approach lets you specify a deployment branch, as well as pin services to specific versions when needed.  The service specified in the orders file with the `<service_git_url>` must support the following:
  1. Serve HTTP traffic to the port number specified in the `PORT` environment variable.  Websockets can also be utilized, but only if the service is served from `/`
  1. Be hosted in a git repository, either publicly available or accessible via key-authenticated git+ssh.
  1. Able to be installed and run with a buildpack.

  The [Linux containers](https://linuxcontainers.org/) which run the services are thrown away on each new service deployment and on each ship reboot.  While local filesystem access is available with a container, it is not persistent and should not be relied upon for persistent data storage.  Note that your `<service_git_url>` **must be network reachable** from each ship in the phleet.

* **remote**: A file specifying data to be autodeployed to to `/var/data/<service_name>` inside the [Linux container](https://linuxcontainers.org/) for `service_name`.  Starphleet symlinks `/var/data/` for all [Linux containers](https://linuxcontainers.org/) to `/var/data/` on the parent ship.  As a result, data specified by the `remote` file is visible to all [Linux container](https://linuxcontainers.org/) instances on a ship.  Only one item is needed inside a `remote` file:

  ```bash
  autodeploy <data_git_url>
  ```

#### ships/
A directory containing files which identify the ships in the phleet.  When configured with a proper `<headquarters_git_url>` and `STARPHLEET_PRIVATE_KEY`, each ship will push back its configuration to a file in this folder.  The name of the file corresponds to the ship's hostname; the file contents contain the IP address to the ship.

The ships themselves are created from a set of virtual machine images in compatible EC2, VMWare, and VirtualBox format. For simplicity, and in the hopes of saving you configuration time, these images are standardized on a single Linux version.  Some may wish to use different base images - all of starphleet is open, feel free to modify as you see fit.

Each ship in the phleet runs every ordered service. This makes things nice and symmetrical, and simplifies scaling. Just add more ships if you need more capacity. If you need full tilt performance, you can easily make a phleet with just one ordered service at `/`. Need a different mixture of services? Launch another phleet!

While each [Linux container](https://linuxcontainers.org/) (and by extension, service) has its own independent directory structure, Starphleet symlinks `/var/data` in each [Linux container](https://linuxcontainers.org/)  to `/var/data` on the ship, allowing

  1. Data that lives between autodeploys of your service.
  1. Collaboration between services

  As `/var/data` is persistent across autodeploys, care must be taken to ensure the ship's storage does not become full.  Also, note that `/var/data/` is a shared **local** fileystem across [Linux containers](https://linuxcontainers.org/) on the same ship.  It does not provide a shared filesystem between ships in a phleet.


#### shipscripts/
A directory containing scripts which will run on individual ships when:

* Starphleet starts
* A change in IP address is detected

Scripts in this folder can be used to implement many different kinds of functionality, including dynamic DNS registration.  If you want to simulate dynamic DNS with Amazon Route53, look at the [starphleet-cli](https://github.com/wballard/starphleet-cli) command `starphleet name ship ec2`.  Note that scripts in this directory **must be marked as [executable](http://www.dslreports.com/faq/linux/7.1_chmod_-_Make_a_file_executable)** in order to run on the ships.  Scripts also run as root on the ships - take care to avoid a shipwreck.

#### jobs
A file which allows scheduling of phleet-level cron tasks to call specified service endpoints.  The `jobs` file uses cron syntax, the only difference being a URL in place of a local command.

```
* * * * * http://localhost/workflow?do=stuff
* * * 1 * http://localhost/workflow?do=modaystuff
```

All [Linux containers](https://linuxcontainers.org/) support `cron`, but the jobs file allows you to dodge a few common problems with cron:

* The logging gets captured to syslog for you automatically and then piped to `logger`.
* The environment is fixed inside your container for your service.
* You don't need to think about which account runs the jobs.
* One-off instances of the jobs can be run manually with curl.

#### .starphleet
A file which contains environment variables that apply to all services in your phleet.  This file is a good place to store usernames, passwords, and connection strings, if your headquarters is in a private, hidden repository reachable by `git+ssh`.  The environment variables set in this file take precedence over all others set elsewhere, and apply to every service deployment within a phleet.


## Environment Variables
Starphleet is configured entirely by environmental variables and encourages the use of custom environment variables.  Some environment variables may apply to certain levels (an individual service or a phleet) or may need to remain private for security reasons (login credentials), and as a result Starphleet will apply environment variables in the following order:

1. **`<service_git_url>/.env`**

  The environment variable file sourced from the root directory of your service (at the root of the `service_git_url` specified in your service `orders` file).  As services will typically be hosted publically, the environment variables added to a `.env` file should concern development mode or public settings, such as `BUILDPACK_URL`.  These variables have the lowest precedence and apply to all of this particular service's deployments, regardless of phleet.

2. **`<headquarters_git_url>/<service_name>/orders`**

  The shell script used to autodeploy your service. Environment variables commonly set here include `PORT`, and apply to all service instances spawned from your headquarters.  These variables have precedence over those set in your service's `.env` file and apply to all of the specified particular service's deployments within a phleet.

3. **`<headquarters_git_url>/.starphleet`**

  The environment variable file which applies to all services in your phleet.  This file is a good place to store usernames, passwords, and connection strings, if your headquarters is in a private, hidden repository reachable by `git+ssh`.  These variables have the highest precedence and apply to every service deployment within a phleet.

### Environment Variable Reference
Name | Value | Description
--- | --- | ---
AWS_ACCESS_KEY_ID | string | Used for [AWS](http://aws.amazon.com) access.  Set this on your workstation prior to using Starphleet.
AWS_SECRET_ACCESS_KEY | string | Used for [AWS](http://aws.amazon.com) access.  Set this on your workstation prior to using Starphleet.
BUILDPACK_URL | &lt;git_url&gt; | Specifies a custom buildpack to be used for autodeployment.  Set this in your Starphleet headquarters or in your service Git repository.
EC2_INSTANCE_SIZE | string | Override the size of EC2 instance with this variable.  Set this on your workstation prior to using Starphleet.
NPM_FLAGS | string | Starphleet uses a custom `npm` registry to just plain run faster, you can use your own here with `--registry <url>`.
PORT | number | This is an **all important environment variable**, and it is expected your service will honor it, publishing traffic here. This `PORT` is used to know where to connect the ship's proxy to your individual service.  Set this in your orders file.
PUBLISH_PORT | number | Allows your service to be accessible on the ship at `http://<SHIP_DNS>:PUBLISH_PORT` in addition to `http://<SHIP_DNS/<service_name>`.  Set this in your orders file.
STARPHLEET_BASE | name | Sets the base Starphleet container, and is either a `name` matching `<starphleet_headquarters_uri>/containers/<container_name>` or a URL to download a prebuilt container image. Defaults to the Starphleet-provided base container.
STARPHLEET_DEPLOY_TIME | date string | Starphleet sets this variable in the [Linux container](https://linuxcontainers.org/) environment for your service to let you know the time of the last deployment.
STARPHLEET_DEPLOY_GITURL | string | Starphleet sets this variable in the [Linux container](https://linuxcontainers.org/) environment to let you know where your running service code came from.
STARPHLEET_HEADQUARTERS | string | <headquarters_git_url>.  Set this on your workstation prior to using Starphleet.
STARPHLEET_PRIVATE_KEY | string | The path to the private keyfile associated with your git repository, such as `~/.ssh/<private_keyfile>`.  Set this on your workstation prior to using Starphleet.
STARPHLEET_PUBLIC_KEY | string | The path to the public keyfile associated with your git repository, such as `~/.ssh/<public_keyfile>`.  Set this on your workstation prior to using Starphleet.
STARPHLEET_PULSE | number | The number of seconds between autodeploy checks, defaulting to a value of 5.  Set this in your Starphleet headquarters or in your service Git repository.
STARPHLEET_REMOTE | &lt;starphleet_git_url&gt; | Allows you to use your own fork of Starphleet itself.  Set this in the .starphleet file in your Starphleet headquarters repository.
STARPHLEET_VAGRANT_MEMSIZE | number | The memory size, in megabytes, of the [Vagrant](http://www.vagrantup.com) instance.  Set this on your workstation prior to using Starphleet.


## Buildpacks
Buildpacks autodetect and provision services in containers for you.  We would like to give a huge thanks to Heroku for having open buildpacks, and to the open source community for making and extending them. The trick that makes the Starphleet orders file so simple is the use of buildpacks and platform package managers to install dynamic, service specific code, such as `rubygems` or` `npm` and associated dependencies, that may vary with each push of your service.  Note that **Starphleet will only deploy one buildpack per Linux container** - for services which are written in multiple languages, extra configuration in the `orders` file may be necessary.

Starphleet currently includes support for Ruby, Python, NodeJS, and NGINX static buildpacks.


### Testing Buildpacks
Sometimes you just want to see the build, or figure out what is going on.  Starphleet lets you directly push to a ship and run a service outside the autodeploy process via a `$ git push`.  You will need to have a public key in the headquarter's `authorized_keys` folder that is matched up with a private key in your local ssh configuration. Remember, you are pushing to the ship, which is just like pushing to any other Git server over ssh.

```bash
$ git remote add ship git@<ship_ip>:<name>
$ git push ship master
```

In the above example, the `name` can be anything you like.


## Maintenance

### Service Start
There is no need in Starphleet to explicitly call `nodemon`, `forever`, or any other keep alive system with your services, Starphleet will fulfill your dependencies and start your service automatically.  In NodeJS projects, this means Starphleet will load the proper buildpack (NodeJS), resolve dependencies by issuing an `$ npm install` command, and then (absent a procfile, see below) start your service by issuing an `$ npm start` command.  In order to use the automatic start functionality, ensure that:

1.  You include functional [procfiles](https://devcenter.heroku.com/articles/procfile) in your service repository, or
2.  You use package manager specific features, such as `npm start` and `npm install` scripts.

### Service Updates
Just commit and push to the repository referenced in your orders file, `<service_git_url>`, which will result in a service autodeployment to every associated ship (even across phleets if a service is used in more than one phleet).  As new versions of services are updated, fresh containers are built and run in parallel to prior versions with a drainstop. As a result, in-process requests to existing services should not interrupted, with one caveat: database and storage systems maintained outside of Starphleet.  Many software components are developed in a database-heavy manner with no real notion of backward compatibility for data storage.  In order to unlock the full benefit of autodeployment and rolling upgrades in Starphleet, you must think about how different versions of your code will interact with your database and storage systems.

#### Healthcheck
Each service repository can supply a `healthcheck` file, located at `<service_git_url>/healthcheck`, which contains a the following content:
  ```bash
  /`<snippet>`
  ```

Upon deployment of a service update, Starphleet will issue a GET request to `http://<container_ip>:PORT/<snippet>`, and will expect an HTTP 200 response within 60 seconds.  The PORT in the preceding URL will have the value of the PORT environment variable specified in your headquarter's `orders` file.

### Service Rollbacks
If bad update goes out to a service, it can be easily reverted by using `$ git revert` to pull out the problem commits, then re-pushing to the `<service_git_url>` referenced in `<headquarters_git_url>/<service_name>/orders`.  This approach also preserves your commit and deploy history.

### Service Crashes
Starphleet monitors running services and will restarts them on failure.

### Starphleet Updates
To check for the latest version of Starphleet and install an update, if needed, run the following:

```bash
$ ssh update@<ship_ip>
```

You will need to run this command on each ship you wish to update and ensure your public key has been added to the authorized\_users/ directory in your Starphleet headquarters.

### Self Healing Phleet
Each ship uses a pull strategy to keep up to date. This strategy has been chosen over push deployments for the following reasons:

* Ships go [up and down](http://en.wikipedia.org/wiki/Heavy-lift_ship#Submerging_types), and a pull-based strategy lets ships catch up easily if they are offline when a new version of a service is released.
* After a new ship is added to the phleet (`$ starphleet add ship`), the pull mechanism will catch it up automatically.
* The developer does not have to wait for a Heroku-style push completes, watching the build go by, and can instead move on to developing the next feature.


## Amazon Web Services

### EC2 Instance Sizes
Don't cheap out and go small. The default instance size in Starphleet is m2.xlarge, which is roughly the power of a decent laptop.  You can change this with by setting the `EC2_INSTANCE_SIZE` environment variable.

### Phleets
Don't feel limited to just one phleet. Part of making your own PaaS is to give you the freedom to mix and match services across phleets as you see fit.

### Geo Scaling AWS
By default, Starphleet sets up four zones, three US, one Europe. Ships are not added to these zones automatically, but instead must be added explicitly.  Again, mix and match zones with phleets as you see fit.  It's OK for you to set up just in one location if you like. Or even have a phleet with one ship.
