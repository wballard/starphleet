# DOCKER-VERSION 0.3.4
FROM ubuntu:precise

RUN apt-get install -y git
RUN apt-get install -y curl

RUN git clone https://github.com/joyent/node.git
RUN cd node; git checkout v0.10.17; ./configure; make; make install

ADD . /src
RUN cd /src; npm install -g
