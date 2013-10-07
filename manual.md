# Overview

This is a toolkit for turning virtual machine infrastructure into a
continuous deployment stack. Looking at what is out there, Starphleet
goes in a problem/solution format:

* Virtualization wastes resources, specifically RAM and CPU running
  multiple operating system images, which costs real money
  * containerization is the new virtualization, using LXC
* PaaS has the same vendor lock-in risks of old proprietary software,
  just without the comptuers
  * full open source is the only way to go
  * allow installation on public as well as private clouds
* Continous deployment is too hard
  * leverage git, allowing deployment with no more than the normal `git
    push`
  * make continuous deployment the default
  * provides drainstop, failover, and rollback as built ins
  * version everything about deployment using simple files rather than
    APIs
* Dependencies suck up time
  * platform package managers, `npm`, `gem`, `apt` beat learning a new
    package/script system just to deploy
  * Heroku Buildpacks already exist for most platforms, use them
* Multiple machines deployment is more work than running locally
  * Make load balancing the default, spanning computers and geographies
* Seeing what is going on across multiple machines is hard
  * aggregate all the logs for each container ship in the phleet, and for
    the entire phleet
