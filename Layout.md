# Overview
This is all about file layout and where we keep things in starphleet.

# Headquarters

## X.orders
[Orders] files are small configurations that describe each ordered
service. You can have as many as you can fit on yoru computer, and lay
them out in subdirectories if you like.

## authorized_keys
Put in public key files here. Each key will be built into a normal
`.ssh/authorized_keys` file for user `admiral`. This is a nice and easy
way for whomever controls the headquarters to hand out keys to the
ships for ssh access.

## config
This is a friendly neightborhood config file, where you can tell your
headquarters about some extra settings. Each one is described below.

### PIG=true
When set to true, local changes to the headquarters repository will be
pushed back to the origin. This provides an ability to do locally
generated dynamic orders which are then shared with other ships when
they pull the headquarters on the normal order update cycle.

## dockerfiles
Put in dockerfiles to be built on your ships here. This is an alternate
to using the docker registry, which we have found slow, particularly to
upload. So, we added the ability to have local docker image builds on
your ship.

Each file in this directory has a `name`, that name will be used to
create a docker image like:

`docker build -t name:sha - < name`

So, net is the name of the docker file is the name of the image, tagged
with the sha from your headquarters, allowing revision of the image.

Reference this in other dockerfiles with:

```
FROM name
```



# On Ship
On ship, the main directory is `/var/starphleet` owned by `admiral`.

## /var/starphleet/current_containers
This will have one `json` file per current running container that
enumerates the publication and port information. This is a hardlink to
the corresponding [info.json], using the instance identifier as a file
name.


This can and will be an array since you can `PUBLISH` multiple ports in
your [Orders].

## /var/starphleet/current_orders
Order's repositories are cloned here, with one directory per order.

### git
This is the git repository with the source to run the order.

### .cid files
This is the current container id. The filename is `image-0.cid` where
image is a tag that refers to a docker image. 0 is an instacen counter
for pooled processes. Each file has the docker instance inside.

### container.json
This is the current output of `docker inspect` for the running
containers serving this order.

### info.json
This contains the port and publication data for the order. This can and
will be an array as you are allowed to have multiple `PUBLISH` clauses.

```json
[{
  "container":"b2ad3ffcb81e2192a02457606dd37558ef939409ecd0acf7972a09145dc5c71e",
  "containerPort":49228,
  "hostPort":80,
  "url":"/echo"
}]
```

### order
The original `.order` file from the headquarters.

## /var/starphleet/private_keys
On occasion you will need to configure starphleet to use private git
repositories over git+ssh. In order to facilitate this, you can put in
private keys, one per file, into this directory. The `admiral`
`~/.ssh/config` is automatically generated from this.

