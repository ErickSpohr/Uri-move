FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

ARG API_URL
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
ARG FIREBASE_API_KEY
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_APP_ID
ARG FIREBASE_MEASUREMENT_ID
ARG FIREBASE_DATABASE_URL

COPY pubspec.yaml pubspec.lock ./
RUN flutter config --no-analytics && flutter pub get

COPY . .

RUN test -n "$API_URL" \
    && flutter build web --release \
      --dart-define="API_URL=$API_URL" \
      --dart-define="SUPABASE_URL=$SUPABASE_URL" \
      --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
      --dart-define="FIREBASE_API_KEY=$FIREBASE_API_KEY" \
      --dart-define="FIREBASE_AUTH_DOMAIN=$FIREBASE_AUTH_DOMAIN" \
      --dart-define="FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID" \
      --dart-define="FIREBASE_STORAGE_BUCKET=$FIREBASE_STORAGE_BUCKET" \
      --dart-define="FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID" \
      --dart-define="FIREBASE_APP_ID=$FIREBASE_APP_ID" \
      --dart-define="FIREBASE_MEASUREMENT_ID=$FIREBASE_MEASUREMENT_ID" \
      --dart-define="FIREBASE_DATABASE_URL=$FIREBASE_DATABASE_URL"

FROM nginx:alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
