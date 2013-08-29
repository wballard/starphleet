# DOCKER-VERSION 0.3.4
FROM ubuntu:precise

RUN apt-get install -y git
RUN apt-get install -y curl
RUN apt-get update -y
RUN apt-get -y dist-upgrade
RUN apt-get install -y nodejs

ADD . /src
RUN cd /src; npm install -g
