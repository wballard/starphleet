FROM wballard/node.v0.10.17

ADD . /src
RUN cd /src; npm install -g
ENTRYPOINT phleet
