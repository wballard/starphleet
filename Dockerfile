# DOCKER-VERSION 0.3.4
FROM ubuntu:precise

RUN apt-get install -y git
RUN apt-get install -y curl
RUN apt-get update -y
RUN apt-get install -y python-software-properties python g++ make
RUN add-apt-repository ppa:chris-lea/node.js
RUN apt-get install -y nodejs

ADD . /src
RUN cd /src; npm install -g
