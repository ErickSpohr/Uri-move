#!/bin/sh
set -eu

if [ -z "${APP_KEY:-}" ] && [ -n "${APP_KEY_BASE64:-}" ]; then
    APP_KEY="base64:${APP_KEY_BASE64}"
    export APP_KEY
fi
if [ -z "${APP_URL:-}" ] && [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
    APP_URL="$RENDER_EXTERNAL_URL"
    export APP_URL
fi
: "${APP_KEY:?Configure a persistent APP_KEY before starting the API}"
: "${DB_CONNECTION:=pgsql}"
export DB_CONNECTION

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    php artisan migrate --force --no-interaction
    php artisan db:seed --class=CampusSeeder --force --no-interaction
    php artisan db:seed --class=CourseSeeder --force --no-interaction
fi

php artisan config:cache --no-interaction
php artisan storage:link --no-interaction
exec apache2-foreground
