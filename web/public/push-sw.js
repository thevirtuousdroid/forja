// Notificações (Web Push) dentro do service worker do app.
// Importado pelo service worker gerado pelo vite-plugin-pwa (workbox.importScripts em vite.config.ts).

/** Só caminhos do próprio app ("/social/avisos"), nunca endereços de fora. */
function safePath(url) {
  return typeof url === 'string' && url.startsWith('/') && !url.startsWith('//') ? url : '/';
}

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = { body: event.data ? event.data.text() : '' };
  }
  // O iPhone já mostra o nome do app em toda notificação. Se o título for só "Forja",
  // a primeira frase do texto vira o título, para não repetir.
  if (!data.title || data.title === 'Forja') {
    const m = /^(.+?[.!?])\s+(.+)$/.exec(data.body || '');
    if (m) { data.title = m[1].replace(/[.!]$/, ''); data.body = m[2]; }
  }
  const options = {
    body: data.body || '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    data: { url: safePath(data.url) },
  };
  // Mesma etiqueta = substitui a anterior (ex.: o lembrete de ontem não fica acumulado)
  if (data.tag) options.tag = String(data.tag);
  // O iPhone exige que todo push mostre uma notificação
  event.waitUntil(self.registration.showNotification(data.title || 'Forja', options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const path = safePath(event.notification.data && event.notification.data.url);
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const w of windows) {
      if (new URL(w.url).origin !== self.location.origin) continue;
      // O app aberto navega sozinho até a tela (sem recarregar)
      w.postMessage({ type: 'forja:abrir', path });
      try {
        await w.focus();
        return;
      } catch (e) {
        break;
      }
    }
    await self.clients.openWindow(path);
  })());
});
