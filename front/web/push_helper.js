// Ponte entre o Flutter e a Push API do navegador (window.uriMovePush).
// Assinaturas são devolvidas como JSON (PushSubscription.toJSON()).
(function () {
  const SCOPE = './push/';

  function base64UrlToBytes(value) {
    const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4));
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  }

  function sameKey(buffer, bytes) {
    if (!buffer) return false;
    const current = new Uint8Array(buffer);
    return current.length === bytes.length && current.every((b, i) => b === bytes[i]);
  }

  // PushManager.subscribe exige um worker ativo.
  function whenActive(registration) {
    if (registration.active) return Promise.resolve(registration);
    const worker = registration.installing || registration.waiting;
    return new Promise((resolve) => {
      worker.addEventListener('statechange', () => {
        if (worker.state === 'activated') resolve(registration);
      });
    });
  }

  async function existingRegistration() {
    return navigator.serviceWorker.getRegistration(SCOPE);
  }

  window.uriMovePush = {
    supported() {
      return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
    },

    permission() {
      return 'Notification' in window ? Notification.permission : 'unsupported';
    },

    async subscribe(publicKey) {
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') return null;

      const registration = await whenActive(
        await navigator.serviceWorker.register('push_sw.js', { scope: SCOPE }),
      );
      const key = base64UrlToBytes(publicKey);
      let subscription = await registration.pushManager.getSubscription();

      // Chave VAPID do servidor mudou: a assinatura antiga não serve mais.
      if (subscription && !sameKey(subscription.options.applicationServerKey, key)) {
        await subscription.unsubscribe();
        subscription = null;
      }

      subscription ??= await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: key,
      });
      return JSON.stringify(subscription.toJSON());
    },

    async current() {
      if (!this.supported() || Notification.permission !== 'granted') return null;
      const registration = await existingRegistration();
      const subscription = registration && (await registration.pushManager.getSubscription());
      return subscription ? JSON.stringify(subscription.toJSON()) : null;
    },

    // Retorna o endpoint removido (para avisar o servidor) ou null.
    async unsubscribe() {
      if (!this.supported()) return null;
      const registration = await existingRegistration();
      const subscription = registration && (await registration.pushManager.getSubscription());
      if (!subscription) return null;
      const endpoint = subscription.endpoint;
      await subscription.unsubscribe();
      return endpoint;
    },
  };
})();
