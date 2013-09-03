# Overview
This is all about file layout and where we keep things in starphleet.

# Headquarters

# On Ship
On ship, the main directory is `/var/starphleet` owned by `admiral`.

## /var/starphleet/current_containers
This will have one `json` file per current running container that
enumerates the publication and port information:

```json
[{
  "container":"b2ad3ffcb81e2192a02457606dd37558ef939409ecd0acf7972a09145dc5c71e",
  "containerPort":49228,
  "hostPort":80,
  "url":"/echo"
}]
```

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

### order
The original `.order` file from the headquarters.

## /var/starphleet/private_keys
On occasion you will need to configure starphleet to use private git
repositories over git+ssh. In order to facilitate this, you can put in
private keys, one per file, into this directory. The `admiral`
`~/.ssh/config` is automatically generated from this.

