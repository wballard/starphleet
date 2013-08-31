FROM node.v0.10.17

ADD . /starphleet
RUN cd /starphleet; npm install -g
RUN npm install -g coffee-script
CMD phleet
