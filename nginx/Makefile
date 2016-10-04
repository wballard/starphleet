SHELL=/usr/bin/env bash
.PHONY: clean unzip

BUILD_ROOT=$(CURDIR)
NGINX_ROOT=$(CURDIR)/nginx-1.11.3
INSTALL_LOCATION=$(CURDIR)/build_output
NGINX=$(CURDIR)/nginx
LUAJIT_LIB=/usr/local/lib/lua/luajit-2.0
LUAJIT_INC=/usr/local/include/luajit-2.0
OPENSSL_VERSION="openssl-1.0.2j"
.EXPORT_ALL_VARIABLES:

${NGINX}: unzip
	mkdir -p ${INSTALL_LOCATION}
	cd ${BUILD_ROOT}/${OPENSSL_VERSION} && ./config && make depend && make
	cd ${BUILD_ROOT}/LuaJIT-2.0.4 && make && make install
	cd ${BUILD_ROOT}/lua-cjson-2.1.0 && make && make install
	cd ${NGINX_ROOT} && ./configure --with-mail --with-http_v2_module --with-mail_ssl_module --with-http_ssl_module \
		--prefix=${INSTALL_LOCATION} \
		--with-ld-opt="-Wl,-rpath,/usr/local/bin/luajit" \
		--with-openssl=${BUILD_ROOT}/${OPENSSL_VERSION} \
		--add-module=${BUILD_ROOT}/headers-more-nginx-module-0.25 \
		--add-module=${BUILD_ROOT}/nginx-auth-ldap \
		--add-module=${BUILD_ROOT}/ngx_devel_kit-0.2.19 \
		--add-module=${BUILD_ROOT}/lua-nginx-module-0.10.5 \
		--with-pcre
	cd ${NGINX_ROOT} && make install
	cp ${INSTALL_LOCATION}/sbin/nginx ${NGINX}

unzip:
	for name in $$(ls *.tar.gz); do tar --no-same-owner --no-same-permissions -xzf $$name; done
clean:
	@echo $(CURDIR)
	@-rm -rf $(INSTALL_LOCATION)
	@-for name in $$(ls *.tar.gz); do DIRNAME=$$(basename -s .tar.gz $$name); test -d $$DIRNAME && rm -rf $$DIRNAME; done
	@-rm -rf ${INSTALL_LOCATION}
	@-rm -f ${NGINX}
	-test -d ${NGINX_ROOT} && cd ${NGINX_ROOT} && make clean
