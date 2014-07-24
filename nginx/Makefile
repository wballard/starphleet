SHELL=/usr/bin/env bash
.PHONY: clean

BUILD_ROOT=$(CURDIR)
INSTALL_LOCATION=$(CURDIR)/build_output
INSTALL_BIN= ${INSTALL_LOCATION}/bin
NGINX=${INSTALL_LOCATION}/sbin/nginx
.EXPORT_ALL_VARIABLES:

${NGINX}: ${INSTALL_LOCATION}
	cd ${BUILD_ROOT}/nginx/ && ./configure  --with-mail --with-mail_ssl_module --with-http_ssl_module \
	 	--prefix=${INSTALL_LOCATION} \
		--add-module=${BUILD_ROOT}/nginx-auth-ldap \
		--with-pcre
	cd ${BUILD_ROOT}/nginx/ && make install

${INSTALL_LOCATION}:
	mkdir -p ${INSTALL_LOCATION}

clean:
	echo $(CURDIR)
	-rm -rf ${INSTALL_LOCATION}
	cd ${BUILD_ROOT}/nginx/ && make clean
