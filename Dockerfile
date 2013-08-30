FROM wballard/node.v0.10.17

ADD . /src
RUN cd /src; npm install -g
VOLUME /var/starphleet:/var/starphleet
ENTRYPOINT phleet
