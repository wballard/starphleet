SHELL=/usr/bin/env bash
.PHONY: clean always

BUILD_ROOT=$(CURDIR)
NGINX_ROOT=$(CURDIR)/nginx-1.7.6
INSTALL_LOCATION=$(CURDIR)/build_output
NGINX=$(CURDIR)/nginx
.EXPORT_ALL_VARIABLES:

${NGINX}: always
	mkdir -p ${INSTALL_LOCATION}
	cd ${NGINX_ROOT} && ./configure --with-http_spdy_module --with-mail --with-mail_ssl_module --with-http_ssl_module \
		--prefix=${INSTALL_LOCATION} \
		--add-module=${BUILD_ROOT}/nginx-auth-ldap \
		--add-module=${BUILD_ROOT}/headers-more-nginx-module-0.25 \
		--with-pcre
	cd ${NGINX_ROOT} && make install
	cp ${INSTALL_LOCATION}/sbin/nginx ${NGINX}

clean:
	echo $(CURDIR)
	-rm -rf ${INSTALL_LOCATION}
	-rm -f ${NGINX}
	cd ${NGINX_ROOT} && make clean
