# Starphleet? What?
The fully open container based continuous deployment PaaS.

[Read the documentation](http://wballard.github.io/starphleet) when you
get a chance.

# Getting Started
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

Yeah, go ahead. Spam me, that's my real email :)

## Locally, Vagrant
Vagrant is a handy way to get a working autodeployment system right on
your laptop inside a virtual machine. Prebuilt base images are provided
in the `Vagrantfile` for both VMWare and VirtualBox. Great for figuring
if your services will autodeploy/start/run without worrying about load
balancing.

```bash
git clone https://github.com/wballard/starphleet.git
cd starphleet
vagrant up
vagrant ssh -c "ifconfig eth0 | grep 'inet addr'"
```

Note the IP address from the last command, you can see the dashboard at
http://ip-address/starphleet/dashboard. This will take a few minutes the
first time.

k

## In the Cloud, AWS
Running on a cloud is ready to go with AWS. In order to get started, you
need to have an AWS account, and the environment variables:

```bash
#these are to appease AWS
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
#this is a public key that starphleet will install on the instances for
#you so that you can ssh to them
export STARPHLEET_PUBLIC_KEY=~/.ssh/wballard@mailframe.net.pub
```

And, to get going

```bash
npm install "git+https://github.com/wballard/starphleet.git"
starphleet --help

starphleet init ec2
starphleet add ship ec2 us-west-1
starphleet info ec2
```

Note the dnsname from the last command, you can see the dashboard at
http://dnsname/starphleet/dashboard.

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

Sometimes you just want to see the build, or figure out what is going on.

Starphleet lets you directly push to a ship and run a service outside
the autodeploy process like this:

```bash
git remote add ship git@$SHIP_IP:name
git push ship master
ssh serve@$SHIP_IP name
#control C when you are bored or done
ssh destroy@$SHIP_IP name
```

This uses a git receive hook, and ssh command accounts (serve and
destroy) to control the process. Your test service will be mounted on
the ship at `http://$SHIP_IP/name`, allowing you to test the service at
an alternate root -- exposing any hardcoded / trouble!
