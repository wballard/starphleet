# Starphleet
**Containers + Buildpacks + Repositories = Autodeploy Services**

Starphleet is a toolkit for turning [virtual](http://aws.amazon.com/ec2/) or physical machine infrastructure into a continuous deployment stack, running multiple Git-backed services on one more more nodes via [OS-level virtualization](https://linuxcontainers.org/).  This approach avoids many of the problems inherent in existing autodeployment solutions:

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

# Concepts

* **The Twelve-Factor App**: Starphleet owes a lot to the [Twelve-Factor App](http://12factor.net). Learn about it.
* **Orders/Services**: The atomic unit of Starphleet.  An individual Ruby, Python, Node, or plain HTML service run in a [Linux container](https://linuxcontainers.org/).
* **Ship**: A virtual machine instances with one or more running orders.
* **Phleet**: A collection of one or more ships.  Phleets are intended to correspond to a single load-and-geo-balanced resource, such as `services.example.com`.
* **Headquarters**: A git repository that instructs the phleet how to operate.

# Get Started
Starphleet is configured entirely by environmental variables.  We are big fans of environment variables, as they save you from the chore of repeatedly typing the same text.

1.  Clone the Starphleet repository to your workstation, then change your current directory to the cloned folder.

  ```bash
  $ git clone https://github.com/wballard/starphleet.git
  $ cd starphleet
  ```

1.  Set the environment variable for the Git URL to your Starphleet headquarters, which is a git repository providing operating instructions for your ships (virtual machine instances) and associated [Linux containers](https://linuxcontainers.org/).  We suggest you start by forking our [base headquarters](https://github.com/wballard/starphleet.headquarters.git).  Your headquarters git URL **must be network reachable** from your hosting cloud, making [public git hosting services](https://github.com/) a natural fit for Starphleet.


  ```bash
  $ export STARPHLEET_HEADQUARTERS=<headquarters_git_url>
  ```

1.  Set the environment variable for the locations of your public and private key files which are associated with the git repository for your Starphleet headquarters.  If you have not yet generated these files, you can do so using [ssh-keygen](https://help.github.com/articles/generating-ssh-keys).  

  ```bash
  $ export STARPHLEET_PRIVATE_KEY=~/.ssh/<private_keyfile>
  $ export STARPHLEET_PUBLIC_KEY=~/.ssh/<public_keyfile>
  ```

After completing the above configuration steps, you can choose to deploy Starphleet (a) on your local workstation using Vagrant, or (b) into the cloud with Amazon Web Services (AWS).

## Locally (Vagrant)

Vagrant is a handy way to get a working autodeployment system inside a virtual machine right on your local workstation. Prebuilt base images are provided in the `Vagrantfile` for VMWare, VirtualBox and Parallels. The Vagrant option is great for figuring if your services will start/run/autodeploy without worrying about cloud configuration.

1.  From the cloned [Starphleet](https://github.com/wballard/starphleet) directory, run `$ vagrant up` in your shell, which will start a new virtual machine instance, perform a git pull on your `STARPHLEET_HEADQUARTERS`, deploy the [Linux containers](https://linuxcontainers.org/), and configure the service(s) specified in the Starphleet headquarters.

  ```bash
  $ vagrant up
  ```
1.  Get the IP address of your new virtual machine instance

  ```bash
  $ vagrant ssh -c "ifconfig eth0 | grep 'inet addr'"
  ```
1.  Navigate in your web browser to `http://<ip_address>/echo`, where `<ip_address>` is returned in the previous step, in order to verify the deployment completed successfully.

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

1.  Use the Starphleet CLI to initialize EC2 and add a ship (virtual machine instance).  Some time will be required while EC2 initially launches the ships, deploys the [Linux containers](https://linuxcontainers.org/), and configures the service(s) specified in the Starphleet headquarters, but subsequent service deployments will be fast.

  ```bash
  $ starphleet init ec2
  $ starphleet add ship ec2 us-west-1
  ```

1.  Get the IP address of your virtual machine instance(s)

  ```bash
  $ starphleet info ec2
  ```

1.  Navigate in your web browser to `http://<ip_address>/echo`, where `<ip_address>` can be any of those returned in the previous step, in order to verify the deployment completed successfully.

## All Running?
Once you are up and running, look in your forked headquarters repository at `echo/orders`. The contents of the orders directory are all that is required to get a web service automatically deploying on the virtualized instances:

* `export PORT=3000` to know on what port your service runs.  This port is mapped, by Starphleet, back to `http://<hostname>/echo` (on port 80).
* `autodeploy https://github.com/wballard/echo.git` to know what to deploy.  Starphleet will automatically deploy your Ruby, Python, Node, and static NGNIX projects (see [buildpacks](#buildbpacks))

Ordering up your own services is just as easy as adding a new directory and creating the `orders` file. Add. Commit. Push. Magic.  Your service will be available , any time that referenced git repo is updated, it will be redeployed to every ship watching your headquarters.

# Reference

## Headquarters
A headquarters is a git repository that instructs the phleet (one or more virtual machine instances) how to operate. Using git in this manner

* Provides a versioned database of your configuation
* Allows editing and working with your own tools
* Provides multiple hosting options
* Avoids the need for a separate Starphleet server

By default, all services are federated together behind one host name. This is particularly useful for single page applications making use of a set of small, sharp back end services, without all the fuss of CORS or other cross domain technique.  Note that the Git URL value assigned to `STARPHLEET_HEADQUARTERS` **must be network reachable** from each ship in the phleet.

### File Structure

Using our [base headquarters](https://github.com/wballard/starphleet.headquarters.git) as an example, we will review the files it contains:

```
authorized_keys/
  wballard@mailframe.net.pub
containers/
echo/
  .htpasswd
  orders
starphleet/
.starphleet
```

#### authorized\_keys/
A directory containing containing public key files, one key per file, which allows ssh access to the ships as follows: `ssh admiral@<ship_uri>`.  Every user shares the same username, `admiral`, which is a member of the sudoers group.  Once pushed to your headquarters, updates to the authorized\_keys/ directory will be reflected on your ships within seconds.  This open ssh access to each ship lets you do what you want, when you want.  If you manage to wreck a ship, you can always add a new one using the [Starphleet CLI](https://github.com/wballard/starphleet-cli).

#### containers/
A directory containing shell scripts to configure a custom [Linux container](https://linuxcontainers.org/) upon which your services will run.  These shell scripts are run as the `ubuntu` user inside the default Starphleet-provided base container, and serve to create fixed, cached sets of software such as compilers, that don't vary with each push of your service.  Note that to use one of these custom containers with your phleet, the `STARPHLEET_BASE` environment variable must be set to match `<starphleet_headquarters_uri>/containers/<container_name>.` container .  script containers diff the script, so as you update the script the container will rebuild

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
  1. Able to be installed and run with a buildpack

  The [Linux containers](https://linuxcontainers.org/) which run the services are thrown away on each new service deployment and on each ship reboot.  While local filesystem access is available with a container, it is not persistent and should not be relied upon for persistent data storage.  Note that your `<service_git_url>` **must be network reachable** from each ship in the phleet.

#### remote
Each [Linux container](https://linuxcontainers.org/) (and by extension, service) has its own directory structure, independent of other containers running on the same ship.  Starphleet mounts `/var/data` in each container back to `/var/data` on the ship, which provides a location to

1. Save data that lives between autodeploys of your service.
2. Collaborate between services if necessary

As `var\data` is persistent across autodeploys, care must be taken to ensure the ship's storage does not become full.  Also, note that this is a shared local fileystem across [Linux containers](https://linuxcontainers.org/) on the same ship.  It does not provide a shared filesystem between ships in a phleet.

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

#### ships/
A directory containing files which identify the ships in the phleet.  When configured with an appropriate git url and private key, each ship will push back its configuration to a file in this folder.  The name of the file corresponds to the ship's hostname and the file contents contain the IP address to the ship.

The ships themselves are created from a set of virtual machine images compatible EC2, VMWare, and VirtualBox format. For simplicity, and in the hopes of saving you configuration time, these images are standardized on a single Linux version.  Some may wish to use different base images - all of starphleet is open, feel free to modify as you see fit.

Each ship in the phleet runs every ordered service. This makes things nice and symmetrical, and simplifies scaling. Just add more ships if you need more capacity. If you need full tilt performance, you can easily make a phleet with just one ordered service at `/`. Need a different mixture of services? Launch another phleet!

#### shipscripts/
A directory containing scripts which will run on individual ships when:

* Starphleet starts
* A change in IP address is detected

Scripts in this folder can be used to implement many different kinds of functionality, including dynamic DNS registration.  If you want to simulate dynamic DNS with Amazon Route53, look at the [starphleet-cli](https://github.com/wballard/starphleet-cli) command `starphleet name ship ec2`.  Note that scripts in this directory **must be marked as [executable](http://www.dslreports.com/faq/linux/7.1_chmod_-_Make_a_file_executable)** in order to run on the ships.  Scripts also run as root on the ships - take care to avoid a shipwreck.

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
AWS_ACCESS_KEY_ID | string | Used for AWS access
AWS_SECRET_ACCESS_KEY | string | Used for AWS access
BUILDPACK_URL | &lt;git_url&gt; | Set this when you want to use a custom buildpack
EC2_INSTANCE_SIZE | string | Override the size of EC2 instance with this variable
NPM_FLAGS | string | Starphleet uses a custom `npm` registry to just plain run faster, you can use your own here with `--registry <url>`
PORT | number | This is an all important environment variable, and it is expected your service will honor it, publishing traffic here. This `PORT` is used to know where to connect the ship's proxy to your individual service.
PUBLISH_PORT | number | Allows your service to be accessible on the ship at `http://<SHIP_DNS>:PUBLISH_PORT` in addition to `http://<SHIP_DNS/<service_name>`.
STARPHLEET_BASE | name | Either a `name` matching `HQ/containers/name, or an URL to download a prebuilt container image. Defaults to the starphleet provided base container
STARPHLEET_DEPLOY_TIME | date string | Set in your service environment to let you know when it was deployed
STARPHLEET_DEPLOY_GITURL | string | Set in your service environment to let you know where the code came from
STARPHLEET_HEADQUARTERS | string | <headquarters_git_url>
STARPHLEET_PRIVATE_KEY | string | ~/.ssh/<private_keyfile>
STARPHLEET_PUBLIC_KEY | string | ~/.ssh/<public_keyfile>
STARPHLEET_PULSE | int | Default 5, number of seconds between autodeploy checks
STARPHLEET_REMOTE | &lt;starphleet_git_url&gt; | Set this in your .starphleet to use your own fork of starphleet itself
STARPHLEET_VAGRANT_MEMSIZE | number | Set vagrant instance memory size, in megabytes

## Buildpacks
Buildpacks autodetect and provision services in containers for you.  We would like to give a huge thanks to Heroku for having open buildpacks, and to the open source community for making and extending them. The trick that makes the starphleet orders file so simple is the use of buildpacks and platform package managers to get your dependencies running.  Buildpacks serve to install dynamic, service specific code such as `npm` or `rubygems` that may vary with each push of your service.  Note that **Starphleet will only deploy one buildpack per Linux container** - for services which are written in multiple languages, extra configuration in the `orders` file may be necessary.

Starphleet currently includes support for Ruby, Python, Node, and NGINX static buildpacks.


### Testing Buildpacks
Sometimes you just want to see the build, or figure out what is going on.  Starphleet lets you directly push to a ship and run a service outside the autodeploy process via a git push.  You will need to have a public key in the `authorized_keys` that is matched up with a private key in your local ssh configuration. Remember, you are pushing to the ship -- so this is just like pushing to any other git server over ssh.

```bash
$ git remote add ship git@<ship_ip>:<name>
$ git push ship master
```

In the above example, the `name` can be anything you like.

## Maintenance

### Service Start
No need to code in `nodemon` or `forever` or any other keep alive system in your services, Starphleet will fulfill your dependencies and spin your service up automatically.  In order to use the automatic start functionality, ensure
1.  You include functional [procfiles](https://devcenter.heroku.com/articles/procfile) in your service repository, or
2.  You use package manager specific features, such as `npm start` and `npm install` scripts.

For node projects, Starphleet will load the proper buildpack (node), resolve dependencies by issuing an `npm install` command, and then, in the absence of a procfile, issue an `npm start` command.

### Service Updates
Just commit and push to the repository referenced in the orders, `<service_git_url>`, which will result in a service autodeployment to every associated ship, even across phleets (if a service is used in more than one phleet).  As new versions of services are updated, fresh containers are built and run in parallel to prior versions with a drainstop. As a result, in-process requests to existing services should not interrupted, with one caveat: database and storage systems maintained outside of Starphleet.  Many software components are developed in a database-heavy manner with no real notion of backward compatibility from a data standpoint.  In order to unlock the full benefit of autodeployment and rolling upgrades in Starphleet, you must think about how different versions of your code will interact with your database and storage systems.

#### Healthcheck
Each service repository can supply a `healthcheck` file, which contains an URL snippet **`http://<container-ip>:<container-port>/<snippet>`**. You supply the `<snippet>`, and if you don't provide it, the default is just blank, meaning hitting the root of your service.

Starphleet considers your service to be online as soon as a HTTP 200 response is returned, and this new service container is put into rotation to take over future requests from the prior version.  In order for this cycling to occur, your new service must respond with a HTTP 200 within 60 seconds of initial startup

### Service Rollbacks
If bad update goes out to a service, it can be easily reverted by using `$ git revert` to pull out the problem commits, then re-pushing to the `<service_git_url>` referenced in `<headquarters_git_url>/<service_name>/orders`.  This approach also preserves your commit and deploy history.

### Service Crashes
Starphleet monitors running services and will restarts them on failure.

### Starphleet Updates
To check for the latest version of Starphleet and install an update, if needed, run the following:

```bash
$ ssh update@ship
```

You will need to run this command on each ship you wish to update and ensure your public key has been added to the authorized\_users/ directory in your Starphleet headquarters.

### Self Healing Phleet
Each ship uses a pull strategy to keep up to date. This strategy has been chosen over push deployments for the following reasons:

* Ships go [up and down](http://en.wikipedia.org/wiki/Heavy-lift_ship#Submerging_types), and a pull-based strategy lets ships catch up easily if they are offline when a new version of a service is released.
* After a new ship is added to the phleet (`$ starphleet add ship`), the pull mechanism will catch it up automatically.
* The developer does not have to wait for a Heroku-style push completes, watching the build go by, and can instead move on to developing the next feature.




## Amazon Web Services

### EC2 Instance Sizes
Don't cheap out and go small. The default instance size in Starphleet is m2.xlarge, which is roughly the power of a decent laptop.  You can change this with `EC2_INSTANCE_SIZE`.

### Phleets
Don't feel limited to just one phleet. Part of making your own PaaS is to give you the freedom to mix and match services across phleets as you see fit.

### Geo Scaling AWS
By default, Starphleet sets up four zones, three US, one Europe. Ships are not added to these zones automatically, but instead must be added explicitly.  Again, mix and match zones with phleets as you see fit.  It's OK for you to set up just in one location if you like. Or even have a phleet with one ship.
