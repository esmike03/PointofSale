FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

FROM php:8.3-fpm-alpine

RUN apk add --no-cache icu-libs libzip oniguruma \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS icu-dev libzip-dev oniguruma-dev \
    && docker-php-ext-install bcmath intl opcache pdo_mysql zip \
    && apk del .build-deps

WORKDIR /var/www/html
COPY --from=vendor /app/vendor ./vendor
COPY . .
COPY deploy/php.ini /usr/local/etc/php/conf.d/pos.ini
COPY deploy/entrypoint.sh /usr/local/bin/pos-entrypoint
RUN chmod +x /usr/local/bin/pos-entrypoint \
    && chown -R www-data:www-data storage bootstrap/cache

ENTRYPOINT ["pos-entrypoint"]
CMD ["php-fpm"]
