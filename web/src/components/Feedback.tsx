import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react';
import { Emblem } from './Emblem';
import { TIER_TITLES, emblemTier } from '../lib/game';

type ToastKind = 'info' | 'error' | 'xp';
interface Toast { id: number; kind: ToastKind; text: string; action?: { label: string; run: () => void } }

interface FeedbackApi {
  toast: (text: string, kind?: ToastKind, action?: Toast['action']) => void;
  levelUp: (level: number) => void;
}

const Ctx = createContext<FeedbackApi>({ toast: () => {}, levelUp: () => {} });
export const useFeedback = () => useContext(Ctx);

export function FeedbackProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [level, setLevel] = useState<number | null>(null);
  const seq = useRef(0);

  const dismiss = useCallback((id: number) => setToasts((t) => t.filter((x) => x.id !== id)), []);

  const toast = useCallback<FeedbackApi['toast']>((text, kind = 'info', action) => {
    const id = ++seq.current;
    setToasts((t) => [...t.slice(-2), { id, kind, text, action }]);
    window.setTimeout(() => dismiss(id), action ? 5000 : 3200);
  }, [dismiss]);

  const levelUp = useCallback((l: number) => {
    setLevel(l);
    if ('vibrate' in navigator) navigator.vibrate?.([30, 40, 60]);
  }, []);

  return (
    <Ctx.Provider value={{ toast, levelUp }}>
      {children}
      <div className="toast-wrap" role="status" aria-live="polite">
        {toasts.map((t) => (
          <div key={t.id} className={`toast ${t.kind}`}>
            <span className="grow">{t.text}</span>
            {t.action && (
              <button className="btn sm ghost" onClick={() => { t.action!.run(); dismiss(t.id); }}>{t.action.label}</button>
            )}
          </div>
        ))}
      </div>
      {level !== null && (
        <div className="overlay" onClick={() => setLevel(null)} role="dialog" aria-label="Você subiu de nível">
          <div className="levelup">
            <span className="tiny muted">Você subiu de nível</span>
            <Emblem level={level} size={160} showLevel={false} />
            <span className="big">{level}</span>
            <span className="muted">{TIER_TITLES[emblemTier(level)]}</span>
            <button className="btn primary" style={{ marginTop: 12 }} onClick={() => setLevel(null)}>Continuar</button>
          </div>
        </div>
      )}
    </Ctx.Provider>
  );
}
