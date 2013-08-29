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
You need a git repository that defines your \<xxx\>. Create a git
repository, and create a single file that looks like this:

**echo.orders**
```
AUTODEPLOY https://github.com/<xxx>/echo.git
PUBLISH 80 /
```

Save it. Awesome. Add it. Commit it. Push it git somewhere you can see.
Call that <my git url>. Get ready to paste that. Make sure you can get
at this without any auth, this sample assume public access.

Fire up a machine with our AMI image or VMWare image. All the tools you
need are preloaded, and self updating from our git.

SSH into your machine, and bootstrap it. Note the <hostname>.

```
phleet join <my git url>
```

Now, we're going to clone that repository for you, and monitor it for
changes. `echo.fleet` will then be used to start up a container. Take a
peek inside that repository, you'll see a `Dockerfile`. This is
mandatory and makes the container work at all. Our echo service isn't
super exciting, but now:

```
curl http://<hostname>/Hi
```

It's exciting, you'll get
```
Hi
```
