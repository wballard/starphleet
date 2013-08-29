# DOCKER-VERSION 0.3.4
FROM ubuntu:precise

RUN apt-get update
RUN apt-get install -y git curl
RUN apt-get install -y build-essential
RUN apt-get install -y openssl libssl-dev pkg-config

RUN git clone https://github.com/joyent/node.git
RUN cd node; git checkout v0.10.17; ./configure; make; make install

ADD . /src
RUN cd /src; npm install -g
