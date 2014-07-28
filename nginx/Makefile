SHELL=/usr/bin/env bash
.PHONY: clean

BUILD_ROOT=$(CURDIR)
NGINX_ROOT=$(CURDIR)/nginx-1.6.0
INSTALL_LOCATION=$(CURDIR)/build_output
NGINX=$(CURDIR)/nginx
.EXPORT_ALL_VARIABLES:

${NGINX}: ${INSTALL_LOCATION}
	cd ${NGINX_ROOT} && ./configure --with-http_spdy_module --with-mail --with-mail_ssl_module --with-http_ssl_module \
	 	--prefix=${INSTALL_LOCATION} \
		--add-module=${BUILD_ROOT}/nginx-auth-ldap \
		--with-pcre
	cd ${NGINX_ROOT} && make install
	cp ${INSTALL_LOCATION}/sbin/nginx ${NGINX}

${INSTALL_LOCATION}:
	mkdir -p ${INSTALL_LOCATION}

clean:
	echo $(CURDIR)
	-rm -rf ${INSTALL_LOCATION}
	cd ${NGINX_ROOT} && make clean
