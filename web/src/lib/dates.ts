/** Datas vêm do servidor como 'AAAA-MM-DD' (dia local do usuário). */
export function parseDay(day: string): Date {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function formatDay(day: string, opts: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short' }) {
  return parseDay(day).toLocaleDateString('pt-BR', opts);
}

export function weekdayShort(day: string) {
  return parseDay(day).toLocaleDateString('pt-BR', { weekday: 'narrow' });
}

export function addDays(day: string, n: number): string {
  const d = parseDay(day);
  d.setDate(d.getDate() + n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function browserTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'America/Sao_Paulo';
  } catch {
    return 'America/Sao_Paulo';
  }
}

export const COMMON_TIMEZONES = [
  'America/Sao_Paulo', 'America/Manaus', 'America/Cuiaba', 'America/Rio_Branco', 'America/Noronha',
  'America/Belem', 'America/Fortaleza', 'America/Recife', 'America/Bahia',
  'Europe/Lisbon', 'America/New_York',
];

export function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}

/** Dia local (AAAA-MM-DD) de um instante, no fuso indicado. */
const formatters = new Map<string, Intl.DateTimeFormat>();
const dayCache = new Map<string, string>();
export function localDay(iso: string, timeZone: string): string {
  const key = iso + '|' + timeZone;
  const hit = dayCache.get(key);
  if (hit) return hit;
  let f = formatters.get(timeZone);
  if (!f) { f = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }); formatters.set(timeZone, f); }
  const v = f.format(new Date(iso));
  if (dayCache.size > 5000) dayCache.clear();
  dayCache.set(key, v);
  return v;
}
