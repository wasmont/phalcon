FROM php:7.4-fpm-alpine
#FROM php:8.1.0-fpm

ENV GROUP_ID=66666
ENV GROUP_NAME=wheel
ENV USER=washington
ENV UID=1000
ARG PSR_VERSION=0.7.0
ENV PHPIZE_DEPS \
		autoconf \
		dpkg-dev dpkg \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkgconf \
		re2c
ENV PHALCON_VERSION 4.0.6


# set your user name, ex: user=joao
# ARG user=washington
# ARG uid=1000

# Install system dependencies
RUN apk update && apk add \
    git \
    curl \
    libpng-dev \
    oniguruma \
    # libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    pcre

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk update && apk upgrade

# Install PHP extensions
RUN docker-php-ext-install mysqli pdo pdo_mysql 
RUN docker-php-ext-install exif pcntl bcmath gd sockets 
RUN apk add php-mbstring

# Add repository
RUN curl -s https://packagecloud.io/install/repositories/phalcon/stable/script.deb.sh

# install phalcon
RUN curl -LO "https://github.com/phalcon/cphalcon/archive/v${PHALCON_VERSION}.tar.gz" \
    && tar xzf "v${PHALCON_VERSION}.tar.gz" \
    && docker-php-ext-install "${PWD}/cphalcon-${PHALCON_VERSION}/build/php7/64bits" \
    && rm -rf v${PHALCON_VERSION}.tar.gz cphalcon-${PHALCON_VERSION} \
    && docker-php-source delete \
    && apk del --purge re2c   

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN apk add doas; \
    adduser ${USER} -G wheel; \
    echo '' | chpasswd; \
    echo 'permit :wheel as root' > /etc/doas.d/doas.conf

RUN apk update

RUN mkdir -p /home/${USER}/.composer && \
    chown -R ${USER}:wheel /home/${USER}

RUN set -xe \
	&& apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS 

    # Download PSR, see https://github.com/jbboehr/php-psr
    #curl -LO https://github.com/jbboehr/php-psr/archive/v${PSR_VERSION}.tar.gz && \
    #tar xzf ${PWD}/v${PSR_VERSION}.tar.gz && \
    #docker-php-ext-install -j $(getconf _NPROCESSORS_ONLN) \
    # ${PWD}/php-psr-${PSR_VERSION}

#PHP-PSR
RUN git clone https://github.com/jbboehr/php-psr.git /root/psr && \
    cd /root/psr && \
    phpize && \
    ./configure && \
    make && \
    make test && \
    make install && \
    echo "extension=psr.so" > /usr/local/etc/php/conf.d/29-psr.ini && \
    cd && rm -Rf /root/psr

RUN pecl install psr \
    && docker-php-ext-enable psr 

# Install redis
RUN pecl install -o -f redis \
    &&  rm -rf /tmp/pear \
    &&  docker-php-ext-enable redis

# Set working directory
WORKDIR /var/www

USER ${USER}
# $user