export type Accent = 'brasa' | 'aco' | 'jade' | 'ametista';

export const ACCENTS: { id: Accent; label: string; color: string }[] = [
  { id: 'brasa', label: 'Brasa', color: '#ff7a3d' },
  { id: 'aco', label: 'Aço azul', color: '#5aa9ff' },
  { id: 'jade', label: 'Jade', color: '#2fd29a' },
  { id: 'ametista', label: 'Ametista', color: '#a77bff' },
];

const KEY = 'forja.accent';

export function getAccent(): Accent {
  try {
    const v = localStorage.getItem(KEY) as Accent | null;
    return v && ACCENTS.some((a) => a.id === v) ? v : 'brasa';
  } catch {
    return 'brasa';
  }
}

export function setAccent(a: Accent) {
  try { localStorage.setItem(KEY, a); } catch { /* armazenamento indisponível */ }
  applyAccent(a);
}

export function applyAccent(a: Accent = getAccent()) {
  if (a === 'brasa') document.documentElement.removeAttribute('data-accent');
  else document.documentElement.setAttribute('data-accent', a);
}
