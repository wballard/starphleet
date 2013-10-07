# Starphleet? What?
The fully open container based continuous deployment PaaS.

[Read the Documentation](http://wballard.github.io/starphleet)

# Getting Started

You need a git repository that defines your **starphleet headquarters**,
you can start up by forking our [base
headquarters](https://github.com/wballard/starphleet.headquarters.git).

Keep track of where you fork it, and for now make sure to use the
**https** version of the url. Call this MY_URL.

## Locally, Vagrant
Vagrant is a handy way to get a working autodeployment system right on
your laptop inside a virtual machine. Prebuilt base images are provided
in the `Vagrantfile` for both VMWare and VirtualBox. Great for hacking
on starphleet itself.

1. clone this repository
2. cd into your clone
3. `vagrant up` ... your ship is built
4. `vagrant ssh`
5. `sudo starphleet-headquarters MY_URL`
6. `ifconfig` ... note your ip address
7. Dashboard at http://ip-address/starphleet/dashboard

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
