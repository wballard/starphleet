# DOCKER-VERSION 0.3.4
FROM wballard/nodejs


ADD . /src
RUN cd /src; npm install -g
