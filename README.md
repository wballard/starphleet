# Starphleet? What? 
This branch is dedicated to creating Docker containers from a headquarters and the associated ordered
repositories.

This is simply a script that you give a `headquarters` URL, which is then synchronized
and if any changes are detected, containers are built.

## Containers
Each ordered service is created into a container by buildpack. This creates a container
at the commit `SHA`, named by the git url, and tagged with both commit `SHA` and `latest`.

## Orders and Environment
A further container is made that will overlay the repository built container with a set of
environment variables from the `orders` and the headquarters root `.starphleet`. This overlay 
approach is designed to let orders vary without a full service rebuild.

## Useage
This script needs to run as a user with full and proper git access to the `headquarters`, all
ordered repositories, and any modules or libraries referenced by those repositories as they build. 

This is accomplished by copying the running user's `~/.ssh to the container as it is built. So, don't run
this as yourself with your keys unless you really want them published to your container registry.


As an example:
```
./scripts/starphleet-dockerize git@github.com:wballard/starphleet.headquarters.git
```