// Notificações no aparelho (Web Push): permissão, inscrição e situação deste aparelho.
// No iPhone, só funcionam com o app instalado na tela de início (iOS 16.4 ou mais novo).
import { api } from './api';

export type PushState =
  | 'unsupported'   // navegador sem notificações (ou iOS antigo)
  | 'install'       // iPhone/iPad no Safari: precisa instalar o app na tela de início
  | 'denied'        // bloqueadas pela pessoa
  | 'default'       // ainda não perguntado
  | 'granted';      // permitidas

export function isIOS(): boolean {
  const ua = navigator.userAgent;
  return /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
}

export function isStandalone(): boolean {
  return window.matchMedia?.('(display-mode: standalone)').matches || (navigator as { standalone?: boolean }).standalone === true;
}

export function pushState(): PushState {
  if (isIOS() && !isStandalone()) return 'install';
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) return 'unsupported';
  return Notification.permission as 'default' | 'denied' | 'granted';
}

export function deviceLabel(): string {
  const ua = navigator.userAgent;
  if (/iPad/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)) return 'iPad';
  if (/iPhone|iPod/.test(ua)) return 'iPhone';
  if (/Android/.test(ua)) return 'Android';
  if (/Macintosh/.test(ua)) return 'Mac';
  if (/Windows/.test(ua)) return 'Windows';
  return 'Navegador';
}

/** Chave pública VAPID (base64url) → bytes, como o PushManager pede. */
export function keyBytes(base64url: string): Uint8Array<ArrayBuffer> {
  const pad = '='.repeat((4 - (base64url.length % 4)) % 4);
  const raw = atob((base64url + pad).replace(/-/g, '+').replace(/_/g, '/'));
  const out = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

function sameKey(sub: PushSubscription, key: Uint8Array): boolean {
  const k = sub.options?.applicationServerKey;
  if (!k) return true;
  const a = new Uint8Array(k);
  return a.length === key.length && a.every((v, i) => v === key[i]);
}

function ready(timeoutMs = 8000): Promise<ServiceWorkerRegistration> {
  return Promise.race([
    navigator.serviceWorker.ready,
    new Promise<never>((_, reject) => setTimeout(() => reject(new Error('push_sem_sw')), timeoutMs)),
  ]);
}

export async function currentSubscription(): Promise<PushSubscription | null> {
  if (!('serviceWorker' in navigator)) return null;
  const reg = await navigator.serviceWorker.getRegistration();
  if (!reg || !reg.pushManager) return null;
  return reg.pushManager.getSubscription();
}

async function save(sub: PushSubscription) {
  const j = sub.toJSON();
  if (!j.endpoint || !j.keys?.p256dh || !j.keys?.auth) throw new Error('inscricao_invalida');
  await api.savePushSubscription(j.endpoint, j.keys.p256dh, j.keys.auth, deviceLabel());
}

// Quem ligou as notificações neste aparelho, e quando foi a última confirmação
const OWNER = 'forja.push.user';
const SYNCED = 'forja.push.sync';
const store = {
  get: (k: string) => { try { return localStorage.getItem(k); } catch { return null; } },
  set: (k: string, v: string) => { try { localStorage.setItem(k, v); } catch { /* sem armazenamento */ } },
  del: (k: string) => { try { localStorage.removeItem(k); } catch { /* sem armazenamento */ } },
};
const todayMark = (uid: string) => `${uid}:${new Date().toISOString().slice(0, 10)}`;

/** Pede permissão e inscreve este aparelho. Chame direto no toque do botão: o iPhone exige. */
export async function enablePush(publicKey: string, userId: string): Promise<void> {
  const perm = await Notification.requestPermission();
  if (perm !== 'granted') throw new Error(perm === 'denied' ? 'push_negado' : 'push_ignorado');
  const reg = await ready();
  const key = keyBytes(publicKey);
  let sub = await reg.pushManager.getSubscription();
  if (sub && !sameKey(sub, key)) { await sub.unsubscribe().catch(() => false); sub = null; }
  sub ??= await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
  await save(sub);
  store.set(OWNER, userId);
  store.set(SYNCED, todayMark(userId));
}

/** Desliga neste aparelho: tira do servidor e cancela no navegador. */
export async function disablePush(): Promise<void> {
  store.del(OWNER);
  store.del(SYNCED);
  const sub = await currentSubscription().catch(() => null);
  if (!sub) return;
  await api.removePushSubscription(sub.endpoint).catch(() => null);
  await sub.unsubscribe().catch(() => false);
}

/**
 * Uma vez por dia, confirma no servidor a inscrição deste aparelho (o navegador pode trocá-la).
 * Só para quem ligou as notificações aqui: outra conta no mesmo aparelho não é inscrita sozinha.
 */
export async function syncPush(userId: string): Promise<void> {
  try {
    if (pushState() !== 'granted' || store.get(OWNER) !== userId || store.get(SYNCED) === todayMark(userId)) return;
    const sub = await currentSubscription();
    if (!sub) return;
    await save(sub);
    store.set(SYNCED, todayMark(userId));
  } catch {
    /* notificação é um extra: nunca atrapalha o app */
  }
}
