/**
 * Onde a versão individual guarda os dados.
 * - Página publicada no claude.ai: banco privado da página (cada pessoa só enxerga o próprio espaço).
 * - Fora do claude.ai (ex.: `npm run dev`): armazenamento do navegador, só neste aparelho.
 *
 * O estado é dividido em documentos: "core" (perfil, plano, avaliações) e um por mês
 * ("m-AAAA-MM", com as missões e o histórico de XP daquele mês), para cada documento
 * ficar pequeno mesmo depois de anos de uso.
 */
import type { GameState, LedgerRow, MissionRow } from './state';

export type Docs = Record<string, Record<string, unknown>>;

export interface Store {
  kind: 'nuvem' | 'aparelho';
  userId: string;
  load(): Promise<Docs>;
  save(name: string, body: Record<string, unknown>): Promise<void>;
  remove(name: string): Promise<void>;
}

// ── Estado ⇄ documentos ─────────────────────────────────────────────────────

export function toDocs(s: GameState): Docs {
  const { missions, ledger, ...core } = s;
  const docs: Docs = { core: core as unknown as Record<string, unknown> };
  const month = (day: string) => `m-${day.slice(0, 7)}`;
  for (const m of missions) {
    const k = month(m.mission_date);
    docs[k] ??= { missions: [], ledger: [] };
    (docs[k].missions as MissionRow[]).push(m);
  }
  for (const l of ledger) {
    const k = month(l.day);
    docs[k] ??= { missions: [], ledger: [] };
    (docs[k].ledger as LedgerRow[]).push(l);
  }
  return docs;
}

export function fromDocs(docs: Docs): GameState | null {
  const core = docs.core as unknown as Omit<GameState, 'missions' | 'ledger'> | undefined;
  if (!core || core.version !== 1) return null;
  const months = Object.keys(docs).filter((k) => k.startsWith('m-')).sort();
  return {
    ...core,
    missions: months.flatMap((k) => (docs[k].missions as MissionRow[]) ?? []),
    ledger: months.flatMap((k) => (docs[k].ledger as LedgerRow[]) ?? []),
  };
}

// ── Banco da página publicada ───────────────────────────────────────────────

type ClaudeWindow = { claude?: { use(name: string): Promise<unknown> } };

interface DbDoc { id: string; data(): Record<string, unknown> | undefined; exists: boolean }
interface DbLike {
  collection(path: string): { get(): Promise<{ docs: DbDoc[] }>; doc(id: string): { set(d: Record<string, unknown>): Promise<void>; delete(): Promise<void> } };
}
interface UserLike { id(): Promise<string | null> }

function withTimeout<T>(p: Promise<T>, ms: number, code: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(code)), ms);
    p.then((v) => { clearTimeout(t); resolve(v); }, (e) => { clearTimeout(t); reject(e); });
  });
}

async function cloudStore(): Promise<Store | null> {
  const w = window as unknown as ClaudeWindow;
  if (typeof w.claude?.use !== 'function') return null;
  const [db, user] = await Promise.all([w.claude.use('db') as Promise<DbLike | null>, w.claude.use('user') as Promise<UserLike | null>]);
  if (!db || !user) return null;
  const uid = await user.id();
  if (!uid) return null;
  const col = db.collection(`data/users/${uid}`);
  return {
    kind: 'nuvem',
    userId: uid,
    async load() {
      const snap = await withTimeout(col.get(), 12000, 'sem_conexao_dados');
      const docs: Docs = {};
      for (const d of snap.docs) if (d.exists) docs[d.id] = d.data() ?? {};
      return docs;
    },
    save: (name, body) => withTimeout(col.doc(name).set(body), 15000, 'falha_ao_salvar'),
    remove: (name) => col.doc(name).delete(),
  };
}

function deviceStore(): Store {
  const prefix = 'forja.v1.';
  const safe = <T,>(fn: () => T, fallback: T) => { try { return fn(); } catch { return fallback; } };
  return {
    kind: 'aparelho',
    userId: 'local',
    async load() {
      const docs: Docs = {};
      safe(() => {
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i)!;
          if (k.startsWith(prefix)) docs[k.slice(prefix.length)] = JSON.parse(localStorage.getItem(k)!);
        }
      }, undefined);
      return docs;
    },
    async save(name, body) {
      try { localStorage.setItem(prefix + name, JSON.stringify(body)); } catch { throw new Error('falha_ao_salvar'); }
    },
    async remove(name) { safe(() => localStorage.removeItem(prefix + name), undefined); },
  };
}

/** Banco da página quando disponível; senão, o navegador. */
export async function openStore(): Promise<Store> {
  try {
    const cloud = await withTimeout(cloudStore(), 12000, 'timeout');
    if (cloud) return cloud;
  } catch { /* cai para o aparelho */ }
  return deviceStore();
}

// ── Gravação: só os documentos que mudaram, um de cada vez ──────────────────

export class Saver {
  private saved = new Map<string, string>();
  private running: Promise<void> = Promise.resolve();
  onError: (e: unknown) => void = () => {};
  onSaved: () => void = () => {};

  constructor(private store: Store) {}

  /** Marca o que já está no armazenamento, para não regravar. */
  baseline(docs: Docs) {
    this.saved = new Map(Object.entries(docs).map(([k, v]) => [k, JSON.stringify(v)]));
  }

  get pending() { return this.dirty.size > 0; }
  private dirty = new Set<string>();

  /** Agenda a gravação do estado atual; devolve quando terminar. */
  persist(state: GameState): Promise<void> {
    const docs = toDocs(state);
    for (const [k, v] of Object.entries(docs)) if (this.saved.get(k) !== JSON.stringify(v)) this.dirty.add(k);
    for (const k of this.saved.keys()) if (!(k in docs)) this.dirty.add(k);
    const snapshot = docs;
    this.running = this.running.then(async () => {
      for (const k of [...this.dirty]) {
        const body = snapshot[k];
        try {
          if (body) {
            const json = JSON.stringify(body);
            if (this.saved.get(k) !== json) await this.store.save(k, body);
            this.saved.set(k, json);
          } else {
            await this.store.remove(k);
            this.saved.delete(k);
          }
          this.dirty.delete(k);
        } catch (e) {
          this.onError(e);
          return;
        }
      }
      this.onSaved();
    });
    return this.running;
  }
}
