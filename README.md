# Starphleet? What?
The fully open container based continuous deployment PaaS.

[Read the Documentation](http://wballard.github.io/starphleet)

# Getting Started

You need a git repository that defines your **starphleet headquarters**,
you can start up by forking our [base
headquarters](https://github.com/wballard/starphleet.headquarters.git).

Keep track of where you fork it, you'll need that git url.
**Important**: the git url must be network reachable from your hosting
cloud, often the best thing to do is use public git hosting services.

I'm a big fan of environment variables, it saves typing repeated stuff.
Paste in your url from above into your shell like this:

```
export STARPHLEET_HEADQUARTERS=<git_url>
```

OK -- so that might not have worked for you, particularly if your
STARPHLEET_HEADQUARTERS was a git/ssh url. To make that work, you need
to have the private key file you use with github, something like mine:

```
export STARPHLEET_PRIVATE_KEY=~/.ssh/wballard@mailframe.net
```

Yeah, go ahead. Spam me, that's my real email :)


## Locally, Vagrant
Vagrant is a handy way to get a working autodeployment system right on
your laptop inside a virtual machine. Prebuilt base images are provided
in the `Vagrantfile` for both VMWare and VirtualBox. Great for figuring
if your services will autodeploy/start/run without worrying about load
balancing.

```
git clone https://github.com/wballard/starphleet.git
cd starphleet
vagrant up
vagrant ssh -c "ifconfig eth0 | grep 'inet addr'"
```
Note the IP address from the last command, you can see the dashboard at
http://ip-address/starphleet/dashboard. And, the ever amazing echo
service that is in the default headquarters can be tested with:

```
curl http://ip-address/echo/hello
```


## Cloudly, AWS
Running on a cloud is ready to go with AWS. In order to get started, you
need to have:

* An AWS account
* AWS_ACCESS_KEY_ID environment variable set
* AWS_SECRET_ACCESS_KEY environment variable set
* A public SSH key that will be used to let you log in

1. `npm install starphleet`
2. `starphleet init MY_URL MY_PRIVATE_KEY_FILENAME MY_PUBLIC_KEY_FILENAME`
3. `starphleet add ship us-west-1`
4. `starphleet info` ... note a DNS name
5. Dashboard at http://dns-name/starphleet/dashboard

## All Running?
Once you are up and running, look in your forked headquarters at
`echo/orders`. This is all it takes to get a web service automatically
deploying:
* `export PORT=` to have a network port for your service
* `autodeploy git_url` to know what to deploy

By default there is now an exciting echo service running, which is
mounted at `/echo`, exactly matching the folder name in the
headquarters. So just:
`curl http://ship/echo/hi`
