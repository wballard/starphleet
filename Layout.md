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

## .starphleet
This is a friendly neightborhood config file, where you can tell your
headquarters about some extra settings. Each one is described below.

### PUSH_HEADQUARTERS=yes
When set to true, local changes to the headquarters repository will be
pushed back to the origin. This provides an ability to do locally
generated dynamic orders which are then shared with other ships when
they pull the headquarters on the normal order update cycle.

The way this works, you will need to either:
* have the credentials in your git url you passed to `headquarters`
* use a git/ssh url and put a file under `/var/starphleet/private_keys`

You probably don't need to use this option.


# On Ship
On ship, the main directory is `/var/starphleet` owned by `admiral`.

## /var/starphleet/current_orders
Order's repositories are cloned here, with one directory per order.

### git
This is the git repository with the source to run the order.

### .container files
Files that track running containers, these contain:
LXC_CONTAINER IP

### order
The original `.order` file from the headquarters.
