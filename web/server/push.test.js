// @vitest-environment node
// Envio das notificações: chaves, criptografia para o aparelho, assinatura VAPID e resultado de cada entrega.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import crypto from 'node:crypto';
import http from 'node:http';
import ece from 'http_ece';
import { processBatch, sendOne } from './push.js';
import handler from '../api/push.js';

// Um "serviço de push" local: guarda o que chega e responde como o da Apple ou do Google
const received = [];
let server;
let base;
beforeAll(async () => {
  server = http.createServer((req, res) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      received.push({ path: req.url, headers: req.headers, body: Buffer.concat(chunks) });
      res.statusCode = req.url === '/gone' ? 410 : req.url === '/erro' ? 500 : 201;
      res.end(req.url === '/erro' ? 'falha interna' : '');
    });
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
afterAll(() => new Promise((r) => server.close(r)));

// Um aparelho: par de chaves P-256 e segredo de autenticação, como o navegador gera
function device() {
  const ecdh = crypto.createECDH('prime256v1');
  ecdh.generateKeys();
  const auth = crypto.randomBytes(16);
  return { ecdh, auth, p256dh: ecdh.getPublicKey().toString('base64url'), authB64: auth.toString('base64url') };
}

function fakeDb({ vapid = null, items = [] }) {
  const calls = [];
  const rpc = async (fn, args) => {
    calls.push({ fn, args });
    if (fn === 'push_claim') return { subject: 'https://app.test', vapid, items };
    if (fn === 'push_set_keys') return { public_key: args.p_public, private_key: args.p_private };
    if (fn === 'push_report') return { ok: args.p_results.filter((r) => r.status === 201).length };
    throw new Error('função inesperada ' + fn);
  };
  return { rpc, calls };
}

function verifyVapid(authorization, audience) {
  const m = /^vapid t=([^,]+), k=(.+)$/.exec(authorization);
  expect(m).not.toBeNull();
  const [h, p, s] = m[1].split('.');
  const raw = Buffer.from(m[2], 'base64url');
  const key = crypto.createPublicKey({
    key: { kty: 'EC', crv: 'P-256', x: raw.subarray(1, 33).toString('base64url'), y: raw.subarray(33, 65).toString('base64url') },
    format: 'jwk',
  });
  const ok = crypto.verify('sha256', Buffer.from(`${h}.${p}`), { key, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url'));
  const claims = JSON.parse(Buffer.from(p, 'base64url').toString());
  return { ok, claims, header: JSON.parse(Buffer.from(h, 'base64url').toString()), publicKey: m[2], audience };
}

describe('envio de um lote', () => {
  it('gera as chaves na primeira vez, envia criptografado e assinado, e informa cada resultado', async () => {
    const a = device();
    const b = device();
    const payload = { title: 'Pedido de amizade', body: 'Leo te mandou um pedido de amizade.', url: '/social/avisos', tag: 'pedido-1' };
    const { rpc, calls } = fakeDb({
      items: [
        { queue: 7, subscription: 's-ok', endpoint: `${base}/ok`, p256dh: a.p256dh, auth: a.authB64, payload, ttl: 600, urgency: 'high' },
        { queue: 7, subscription: 's-gone', endpoint: `${base}/gone`, p256dh: b.p256dh, auth: b.authB64, payload, ttl: 600, urgency: 'high' },
      ],
    });
    received.length = 0;
    const out = await processBatch('a'.repeat(64), { rpc });

    expect(calls.map((c) => c.fn)).toEqual(['push_claim', 'push_set_keys', 'push_report']);
    const keys = calls[1].args;
    expect(keys.p_public).toMatch(/^[A-Za-z0-9_-]{87}$/);
    expect(keys.p_private).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(out.keys_created).toBe(true);

    const results = calls[2].args.p_results;
    expect(results).toEqual([
      { queue: 7, subscription: 's-ok', status: 201, error: null },
      { queue: 7, subscription: 's-gone', status: 410, error: 'HTTP 410' },
    ]);

    // O que chegou ao "serviço de push" para o aparelho A
    const req = received.find((r) => r.path === '/ok');
    expect(req.headers['content-encoding']).toBe('aes128gcm');
    expect(req.headers['content-type']).toBe('application/octet-stream');
    expect(req.headers.ttl).toBe('600');
    expect(req.headers.urgency).toBe('high');
    // Só o aparelho consegue abrir
    const plain = ece.decrypt(req.body, { version: 'aes128gcm', privateKey: a.ecdh, authSecret: a.auth });
    expect(JSON.parse(plain.toString())).toEqual(payload);
    expect(() => ece.decrypt(req.body, { version: 'aes128gcm', privateKey: b.ecdh, authSecret: b.auth })).toThrow();
    // Assinatura VAPID válida, com a chave pública que o app usa para se inscrever
    const v = verifyVapid(req.headers.authorization);
    expect(v.ok).toBe(true);
    expect(v.header).toMatchObject({ alg: 'ES256', typ: 'JWT' });
    expect(v.publicKey).toBe(keys.p_public);
    expect(v.claims.aud).toBe(base);
    expect(v.claims.sub).toBe('https://app.test');
    expect(v.claims.exp - Date.now() / 1000).toBeLessThanOrEqual(24 * 3600);
  });

  it('usa as chaves que já existem e não gera outras', async () => {
    const a = device();
    const k = (await import('web-push')).default.generateVAPIDKeys();
    const { rpc, calls } = fakeDb({
      vapid: { public_key: k.publicKey, private_key: k.privateKey },
      items: [{ queue: 1, subscription: 's1', endpoint: `${base}/ok`, p256dh: a.p256dh, auth: a.authB64, payload: { title: 'x' }, ttl: 60 }],
    });
    received.length = 0;
    const out = await processBatch('b'.repeat(64), { rpc });
    expect(calls.map((c) => c.fn)).toEqual(['push_claim', 'push_report']);
    expect(out.keys_created).toBe(false);
    expect(verifyVapid(received[0].headers.authorization).publicKey).toBe(k.publicKey);
    expect(received[0].headers.urgency).toBe('normal');
  });

  it('erro do serviço e falta de resposta viram resultado, sem derrubar o lote', async () => {
    const a = device();
    const k = (await import('web-push')).default.generateVAPIDKeys();
    const vapid = { public_key: k.publicKey, private_key: k.privateKey };
    const item = { queue: 1, subscription: 's', p256dh: a.p256dh, auth: a.authB64, payload: { title: 'x' }, ttl: 60 };
    expect(await sendOne({ ...item, endpoint: `${base}/erro` }, vapid, 'https://app.test'))
      .toEqual({ status: 500, error: 'falha interna' });
    const offline = await sendOne({ ...item, endpoint: 'http://127.0.0.1:9/nada' }, vapid, 'https://app.test');
    expect(offline.status).toBe(0);
    expect(offline.error).toBeTruthy();
    // Inscrição corrompida também não derruba
    const bad = await sendOne({ ...item, endpoint: `${base}/ok`, p256dh: 'xx' }, vapid, 'https://app.test');
    expect(bad.status).toBe(0);
  });
});

describe('função /api/push', () => {
  function res() {
    const r = { code: 0, body: null, headers: {} };
    return Object.assign(r, {
      status(c) { r.code = c; return r; },
      json(b) { r.body = b; return r; },
      setHeader(k, v) { r.headers[k] = v; },
    });
  }
  it('só aceita POST com um código de lote bem formado', async () => {
    let r = res();
    await handler({ method: 'GET' }, r);
    expect(r.code).toBe(405);
    r = res();
    await handler({ method: 'POST', body: { token: 'curto' } }, r);
    expect(r.code).toBe(400);
    r = res();
    await handler({ method: 'POST', body: '{"token":"' + 'c'.repeat(64) + '"}' }, r);
    // Sem as variáveis do Supabase neste teste
    expect(r.code).toBe(500);
  });
});
