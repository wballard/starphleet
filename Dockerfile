FROM base

RUN apt-get -y install software-properties-common python g++ make git
RUN add-apt-repository ppa:chris-lea/node.js
RUN apt-get update
RUN apt-get -y install nodejs

ADD . /starphleet
RUN cd /starphleet; npm install -g
RUN npm install -g coffee-script
CMD phleet
