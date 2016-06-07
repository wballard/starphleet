SHELL=/usr/bin/env bash
.PHONY: clean always

BUILD_ROOT=$(CURDIR)
NGINX_ROOT=$(CURDIR)/nginx-1.7.6
INSTALL_LOCATION=$(CURDIR)/build_output
NGINX=$(CURDIR)/nginx
LUAJIT_LIB=/usr/local/lib/lua/luajit-2.0
LUAJIT_INC=/usr/local/include/luajit-2.0
.EXPORT_ALL_VARIABLES:

${NGINX}: always
	mkdir -p ${INSTALL_LOCATION}
	cd ${BUILD_ROOT}/LuaJIT-2.0.4 && make && make install
	cd ${BUILD_ROOT}/lua-cjson-2.1.0 && make && make install
	cd ${NGINX_ROOT} && ./configure --with-http_spdy_module --with-mail --with-mail_ssl_module --with-http_ssl_module \
		--prefix=${INSTALL_LOCATION} \
		--with-ld-opt="-Wl,-rpath,/usr/local/bin/luajit" \
		--add-module=${BUILD_ROOT}/headers-more-nginx-module-0.25 \
		--add-module=${BUILD_ROOT}/nginx-auth-ldap \
		--add-module=${BUILD_ROOT}/ngx_devel_kit-0.2.19 \
		--add-module=${BUILD_ROOT}/lua-nginx-module-0.9.20 \
		--with-pcre
	cd ${NGINX_ROOT} && make install
	cp ${INSTALL_LOCATION}/sbin/nginx ${NGINX}

clean:
	echo $(CURDIR)
	-rm -rf ${INSTALL_LOCATION}
	-rm -f ${NGINX}
	cd ${NGINX_ROOT} && make clean

