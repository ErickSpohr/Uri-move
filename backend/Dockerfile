FROM php:8.5-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libpq-dev libicu-dev libzip-dev libonig-dev \
    && docker-php-ext-install pdo_pgsql intl zip mbstring bcmath opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html
ENV APP_ENV=production APP_DEBUG=false PORT=8080 LOG_CHANNEL=stderr

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY . .
RUN composer dump-autoload --no-dev --optimize --no-interaction \
    && mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs \
    && chown -R www-data:www-data storage bootstrap/cache

COPY deploy/apache.conf /etc/apache2/sites-available/000-default.conf
COPY deploy/ports.conf /etc/apache2/ports.conf
COPY deploy/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
COPY deploy/opcache.ini /usr/local/etc/php/conf.d/zz-opcache.ini
COPY deploy/start.sh /usr/local/bin/uri-move-start
RUN chmod +x /usr/local/bin/uri-move-start

EXPOSE 8080
CMD ["/usr/local/bin/uri-move-start"]
