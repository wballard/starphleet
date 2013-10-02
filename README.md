# Starphleet? What?
Virtualization is awesome. Much faster than getting another machine.
Containerization is faster still. Fast is good.

What we really want is an open toolkit to turn machines, either physical
or virtual, into container hosts. It needs to:

* be really fast
* run containers across multiple machines (container ships), creating
  clusters, which we call phleets
* leverage git as the backbone
* use simple files for configuration, no APIs
* run applications at a git ref
* autodeploy new versions as a git ref advances
* drainstop and switch users to new versions transparently
* aggregate all the logs for each container ship in the phleet, and for
  the entire phleet
* aggregate metadata about networking and performance for each container

# Getting Started
You need a git repository that defines your **starphleet headquarters**.
Create a git repository, and create a single file that looks like this:

**echo.orders**
```
autodeploy https://github.com/wballard/echo.git
publish --private 3000 --public 80  --url /echo
```

Save it. Awesome. Add it. Commit it. Push it git somewhere you can see.
Call that \<my git url\>. Get ready to paste that. Make sure you can get
at this without any auth, this sample assume public access.

Fire up a machine with our AMI image or VMWare image. All the tools you
need are preloaded, and self updating from our git. Any easy way to do
this is with the `Vagrantfile` in this repository.

SSH into your machine, and bootstrap it.

```
starphleet-headquarters <my git url>
```

Now, we're going to clone that repository for you on the virtual
machine, which we call a *ship*, and monitor it for changes. That
[echo.git](https://github.com/wballard/echo.git) will then be used to
start up a container. Take a peek inside that repository, you'll see a
`Starphleet`. This is mandatory and makes the container work at all. Our
echo service isn't super exciting, but now:

```
curl http://<hostname>/echo/Hi
```

It's exciting, you'll get
```
Hi
```


# Karsten Notes
Wasn't super clear that --port means your service.
Need a check on the public key.
Need a check that the load balancer is online, quicker health check
Would be great to have a tarball of the base container and speed that up
Message if you create a crap ordera nd thus bust nginx


