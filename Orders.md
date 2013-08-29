# Ship's Orders
You give orders to the ships in your phleet with a simple config DSL.
These orders are checked into your Headquarters repository, which each
ship in the fleet contacts.

# Commands
The commands are noted here.

## AUTODEPLOY
## PUBLISH
## FORK
## HEALTHCHECK

# Using It
Ships orders are filed, literally in files, with the Headquarters -- the
git repository that controls a fleet. You file orders with headquarters
to tell ships which containers to service. Hopefully this nautical
analogy makes sense to everyone.

## Dockerfile
Each container repository is expected to have a Dockerfile in the root of its
repository. This is used to configure the container.

The container repository will be cloned ont your ship, the container
started, and the repository files copied onto the container at `/repo`.
You can have other copies made inside your Dockerfile if you like, but
there will always be at least this one.

You will need to have a `CMD` or `ENTRYPOINT` in your Dockerfile,
otherwise your container isn't going to do very much.

