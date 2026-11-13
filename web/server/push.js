// Envio das notificações (Web Push) de um lote preparado pelo banco.
//
// O banco cria o lote e chama /api/push só com um código de uso único. Com esse código, esta função:
//   1. pega o lote no Supabase (push_claim), usando a chave pública do app;
//   2. na primeira vez, gera o par de chaves VAPID e guarda no banco (push_set_keys);
//   3. envia cada notificação, criptografada para o aparelho (aes128gcm) e assinada com a chave VAPID;
//   4. devolve o resultado de cada entrega (push_report).
// Nada fica guardado aqui: as chaves e as inscrições vivem só no banco.
import webpush from 'web-push';

const SEND_TIMEOUT_MS = 10_000;
const PARALLEL = 8;

/** Chama uma função do banco pelo PostgREST do Supabase, como o app faz. */
export function supabaseRpc(url, key) {
  return async function rpc(fn, args) {
    const r = await fetch(`${url.replace(/\/$/, '')}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(args),
      signal: AbortSignal.timeout(10_000),
    });
    const text = await r.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { /* resposta não-JSON */ }
    if (!r.ok) {
      const err = new Error((data && data.message) || `HTTP ${r.status}`);
      err.status = r.status;
      throw err;
    }
    return data;
  };
}

/** Envia uma notificação para um aparelho. Nunca lança erro: devolve o status (0 = sem resposta). */
export async function sendOne(item, vapid, subject, doFetch = fetch) {
  try {
    const details = webpush.generateRequestDetails(
      { endpoint: item.endpoint, keys: { p256dh: item.p256dh, auth: item.auth } },
      JSON.stringify(item.payload ?? {}),
      {
        vapidDetails: { subject, publicKey: vapid.public_key, privateKey: vapid.private_key },
        TTL: Number.isFinite(item.ttl) ? item.ttl : 3600,
        urgency: ['very-low', 'low', 'normal', 'high'].includes(item.urgency) ? item.urgency : 'normal',
      },
    );
    const headers = {};
    for (const [k, v] of Object.entries(details.headers)) {
      if (k.toLowerCase() !== 'content-length') headers[k] = String(v);
    }
    const r = await doFetch(details.endpoint, {
      method: details.method,
      headers,
      body: details.body,
      signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
    });
    let error = null;
    if (!r.ok) error = (await r.text().catch(() => '')).slice(0, 200) || `HTTP ${r.status}`;
    return { status: r.status, error };
  } catch (e) {
    return { status: 0, error: String((e && e.message) || e).slice(0, 200) };
  }
}

async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return out;
}

/** Processa um lote inteiro. `rpc` chama o banco; `doFetch` envia (trocável nos testes). */
export async function processBatch(token, { rpc, doFetch = fetch, generateKeys = webpush.generateVAPIDKeys }) {
  const batch = await rpc('push_claim', { p_token: token });
  let vapid = batch && batch.vapid;
  let createdKeys = false;
  if (!vapid || !vapid.public_key) {
    const k = generateKeys();
    vapid = await rpc('push_set_keys', { p_token: token, p_public: k.publicKey, p_private: k.privateKey });
    createdKeys = vapid.public_key === k.publicKey;
  }
  const items = Array.isArray(batch.items) ? batch.items : [];
  const results = await mapLimit(items, PARALLEL, async (it) => {
    const { status, error } = await sendOne(it, vapid, batch.subject, doFetch);
    return { queue: it.queue, subscription: it.subscription, status, error };
  });
  const report = await rpc('push_report', { p_token: token, p_results: results });
  return { keys_created: createdKeys, total: results.length, report };
}
