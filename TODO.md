* Create a base image with Docker
* Command line `phleet` program, script link to a Docker container with
  npm, run our command inside docker on the host
* Make sure Docker is set to autorestart stuff


* Program to tell a ship what where is the headquarters
* Program to pull the headquarters and iterate all the orders
* Program to take orders and generate the correct nginx include snip for
the current version
* Program to take orders and build and run the container at a version
* Queue up any new versions, process the queue
  * for each item in the queue, HEALTHCHECK and HUP
  * if the HEALTHCHECK is missing or doesn't pass, start it anyhow
  * alert if we started with a failing HEALTHCHECK

