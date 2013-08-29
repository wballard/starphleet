# DOCKER-VERSION 0.3.4
FROM    ubuntu:precise

RUN apt-get install -y git
RUN apt-get install -y curl
# install nvm
RUN curl https://raw.github.com/creationix/nvm/master/install.sh | sh

ADD . /app_src
# Install app dependencies
RUN /bin/bash -c 'source .nvm/nvm.sh; cd /app_src; nvm install 0.10.10; nvm alias default 0.10.10 ; npm install'
CMD /bin/bash -c 'source .nvm/nvm.sh; nvm ls ; node --version'
