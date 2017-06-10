# wunder/fuzzy-alpine-nginx-pagespeed
#
# VERSION v1.11.7-1
#
FROM php:7.1.3-fpm-alpine
MAINTAINER powernic@list.ru

# Based on https://github.com/pagespeed/ngx_pagespeed/issues/1181#issuecomment-250776751.
# Secret Google tarball releases of mod_pagespeed from here https://github.com/pagespeed/mod_pagespeed/issues/968.

# Set versions as environment variables so that they can be inspected later.

ENV php_conf /usr/local/etc/php-fpm.conf
ENV fpm_conf /usr/local/etc/php-fpm.d/www.conf
ENV php_vars /usr/local/etc/php/conf.d/docker-vars.ini

ENV LIBPNG_VERSION=1.2.56 \
    # mod_pagespeed requires an old version of http://www.libpng.org/pub/png/libpng.html.
    PAGESPEED_VERSION=1.11.33.4 \
    # Check https://github.com/pagespeed/ngx_pagespeed/releases for the latest version.
    NGINX_VERSION=1.11.7
    # Check http://nginx.org/en/download.html for the latest version.

# Add dependencies.
RUN apk --no-cache add \
        ca-certificates \
        libuuid \
        apr \
        apr-util \
        libjpeg-turbo \
        icu \
        icu-libs \
        openssl \
        pcre \
        zlib

# Add build dependencies
# and build mod_pagespeed from source for Alpine for Nginx with ngx_pagespeed.
RUN set -x && \
    apk --no-cache add -t .build-deps \
		gcc \
		libc-dev \
		apache2-dev \
		apr-dev \
		apr-util-dev \
		build-base \
		curl \
		icu-dev \
		libjpeg-turbo-dev \
		linux-headers \
		gperf \
		openssl-dev \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		perl-dev \
		pcre-dev \
		python \
		zlib-dev && \
    # Build libpng.
	cd /tmp && \
	curl -L http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz | tar -zx && \
	cd /tmp/libpng-${LIBPNG_VERSION} && \
	./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
	make install V=0 && \
	# Build PageSpeed.
	cd /tmp && \
	curl -L https://dl.google.com/dl/linux/mod-pagespeed/tar/beta/mod-pagespeed-beta-${PAGESPEED_VERSION}-r0.tar.bz2 | tar -jx && \
	curl -L https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-beta.tar.gz | tar -zx && \
	cd /tmp/modpagespeed-${PAGESPEED_VERSION} && \
	curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/automatic_makefile.patch | patch -p1 && \
	curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/libpng_cflags.patch | patch -p1 && \
	curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/pthread_nonrecursive_np.patch | patch -p1 && \
	curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/rename_c_symbols.patch | patch -p1 && \
	curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/stack_trace_posix.patch | patch -p1 && \
	./generate.sh -D use_system_libs=1 -D _GLIBCXX_USE_CXX11_ABI=0 -D use_system_icu=1 && \
	cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src && \
	make BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
	cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/ && \
	make psol BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
	mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol && \
	mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
	mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/out/Release/obj /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release/ && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/net /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/testing /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/third_party /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/tools /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/url /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
	cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/pagespeed_automatic.a /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64

RUN cd /tmp && \
    curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
    cd /tmp/nginx-${NGINX_VERSION} && \
    LD_LIBRARY_PATH=/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
        --add-module=/tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta \
        --with-cc-opt="-fPIC -I /usr/include/apr-1" \
        --with-ld-opt="-luuid -lapr-1 -laprutil-1 -licudata -licuuc -L/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib -lpng12 -lturbojpeg -ljpeg" && \
	make install --silent && \
    # Make sure /etc/nginx/conf.d folder is available for images extending
    # this one.
	rm -rf /etc/nginx/html/ && \
	mkdir /etc/nginx/conf.d/ && \
    mkdir -p /etc/nginx/conf.d && \
	mkdir -p /usr/share/nginx/html/ && \
	install -m644 html/index.html /usr/share/nginx/html/ && \
	install -m644 html/50x.html /usr/share/nginx/html/ && \
	ln -s ../../usr/lib/nginx/modules /etc/nginx/modules && \
	strip /usr/sbin/nginx* && \
	strip /usr/lib/nginx/modules/*.so && \
    # Clean-up.
    cd && \
    apk del .build-deps && \
    rm -rf /tmp/* && \
    # Forward request and error logs to docker log collector.
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    # Make PageSpeed cache writable.
    mkdir -p /var/cache/ngx_pagespeed && \
    chmod -R o+wr /var/cache/ngx_pagespeed

RUN echo @testing http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
#    sed -i -e "s/v3.4/edge/" /etc/apk/repositories && \
    echo /etc/apk/respositories && \
    apk update && \
    apk add --no-cache bash \
    openssh-client \
    wget \
    supervisor \
    curl \
    libcurl \
    git \
    python \
    python-dev \
    py-pip \
    augeas-dev \
    openssl-dev \
    ca-certificates \
    dialog \
    gcc \
    musl-dev \
    linux-headers \
    libmcrypt-dev \
    libpng-dev \
    icu-dev \
    libpq \
    libxslt-dev \
    libffi-dev \
    freetype-dev \
    sqlite-dev \
    libjpeg-turbo-dev && \
    docker-php-ext-configure gd \
      --with-gd \
      --with-freetype-dir=/usr/include/ \
      --with-png-dir=/usr/include/ \
      --with-jpeg-dir=/usr/include/ && \
    #curl iconv session
    docker-php-ext-install pdo_mysql pdo_sqlite mysqli mcrypt gd exif intl xsl json soap dom zip opcache && \
    docker-php-source delete && \
    mkdir -p /etc/nginx && \
    mkdir -p /var/www/app && \
    mkdir -p /run/nginx && \
    mkdir -p /var/log/supervisor && \
    EXPECTED_COMPOSER_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig) && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '${EXPECTED_COMPOSER_SIGNATURE}') { echo 'Composer.phar Installer verified'; } else { echo 'Composer.phar Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php --install-dir=/usr/bin --filename=composer && \
    php -r "unlink('composer-setup.php');"  && \
    pip install -U pip && \
    pip install -U certbot && \
    mkdir -p /etc/letsencrypt/webrootauth && \
    apk del gcc musl-dev linux-headers libffi-dev augeas-dev python-dev
#    ln -s /usr/bin/php7 /usr/bin/php

ADD conf/supervisord.conf /etc/supervisord.conf

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD conf/nginx.conf /etc/nginx/nginx.conf

# nginx site conf
RUN mkdir -p /etc/nginx/sites-available/ && \
mkdir -p /etc/nginx/sites-enabled/ && \
mkdir -p /etc/nginx/ssl/ && \
rm -Rf /var/www/* && \
mkdir /var/www/html/
ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
ADD conf/nginx-site-ssl.conf /etc/nginx/sites-available/default-ssl.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# tweak php-fpm config
RUN echo "cgi.fix_pathinfo=0" > ${php_vars} &&\
    echo "upload_max_filesize = 100M"  >> ${php_vars} &&\
    echo "post_max_size = 100M"  >> ${php_vars} &&\
    echo "variables_order = \"EGPCS\""  >> ${php_vars} && \
    echo "memory_limit = 128M"  >> ${php_vars} && \
    sed -i \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 5/pm.max_children = 4/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 3/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" \
        -e "s/;pm.max_requests = 500/pm.max_requests = 200/g" \
        -e "s/user = www-data/user = nginx/g" \
        -e "s/group = www-data/group = nginx/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/;listen.owner = www-data/listen.owner = nginx/g" \
        -e "s/;listen.group = www-data/listen.group = nginx/g" \
        -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        ${fpm_conf}
#    ln -s /etc/php7/php.ini /etc/php7/conf.d/php.ini && \
#    find /etc/php7/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

#redis install
RUN curl -L -o /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/php7.tar.gz \
	&& tar xfz /tmp/redis.tar.gz \
    && rm -r /tmp/redis.tar.gz \
	&& mkdir -p /usr/src/php/ext \
	&& mv phpredis-php7 /usr/src/php/ext/redis \
	&& docker-php-ext-install redis

	
# Add Scripts
ADD scripts/start.sh /start.sh
ADD scripts/pull /usr/bin/pull
ADD scripts/push /usr/bin/push
ADD scripts/letsencrypt-setup /usr/bin/letsencrypt-setup
ADD scripts/letsencrypt-renew /usr/bin/letsencrypt-renew
RUN chmod 755 /usr/bin/pull && chmod 755 /usr/bin/push && chmod 755 /usr/bin/letsencrypt-setup && chmod 755 /usr/bin/letsencrypt-renew && chmod 755 /start.sh

# copy in code
ADD src/ /var/www/html/
ADD errors/ /var/www/errors

VOLUME /var/www/html

EXPOSE 443 80

CMD ["/start.sh"]