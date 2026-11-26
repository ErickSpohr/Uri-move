// Service worker dedicado ao Web Push. Escopo "./push/" para não interferir
// em nenhum service worker do Flutter registrado na raiz.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }

  event.waitUntil(
    self.registration.showNotification(data.title || 'URI Move', {
      body: data.body || '',
      icon: new URL('../icons/Icon-192.png', self.registration.scope).href,
      badge: new URL('../icons/Icon-maskable-192.png', self.registration.scope).href,
      tag: data.notification_id ? `notification-${data.notification_id}` : undefined,
      data: { rideId: data.ride_id || null },
    }),
  );
});

// Clique na notificação: foca uma aba já aberta do app ou abre uma nova.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const appUrl = new URL('../', self.registration.scope).href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if (client.url.startsWith(appUrl) && 'focus' in client) {
          return client.focus();
        }
      }
      return self.clients.openWindow(appUrl);
    }),
  );
});
