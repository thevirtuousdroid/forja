import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react';

type ToastKind = 'info' | 'error' | 'xp';
interface Toast { id: number; kind: ToastKind; text: string; action?: { label: string; run: () => void } }

interface FeedbackApi {
  toast: (text: string, kind?: ToastKind, action?: Toast['action']) => void;
}

const Ctx = createContext<FeedbackApi>({ toast: () => {} });
export const useFeedback = () => useContext(Ctx);

/** Avisos rápidos no topo da tela. Recompensas maiores ficam no RewardOverlay. */
export function FeedbackProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const seq = useRef(0);

  const dismiss = useCallback((id: number) => setToasts((t) => t.filter((x) => x.id !== id)), []);

  const toast = useCallback<FeedbackApi['toast']>((text, kind = 'info', action) => {
    const id = ++seq.current;
    setToasts((t) => [...t.slice(-2), { id, kind, text, action }]);
    window.setTimeout(() => dismiss(id), action ? 5000 : 3200);
  }, [dismiss]);

  return (
    <Ctx.Provider value={{ toast }}>
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
    </Ctx.Provider>
  );
}
