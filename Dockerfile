FROM node.v0.10.17

RUN apt-get -y install git

ADD . /src
RUN cd /src; npm install -g
