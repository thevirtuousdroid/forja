import { useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';
import { friendlyError } from '../lib/api';

export function AuthScreen() {
  const [mode, setMode] = useState<'entrar' | 'criar'>('entrar');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null); setInfo(null); setBusy(true);
    try {
      if (mode === 'criar') {
        const { data, error } = await supabase.auth.signUp({
          email: email.trim(), password,
          options: { data: { name: name.trim() }, emailRedirectTo: window.location.origin },
        });
        if (error) throw error;
        if (!data.session) setInfo('Conta criada! Enviamos um link de confirmação para o seu e-mail. Depois de confirmar, é só entrar.');
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
        if (error) throw error;
      }
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  }

  async function resetPassword() {
    if (!email.trim()) { setError('Digite seu e-mail acima para receber o link.'); return; }
    setError(null);
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: window.location.origin });
    if (error) setError(friendlyError(error));
    else setInfo('Se existir uma conta com esse e-mail, você vai receber um link para redefinir a senha.');
  }

  return (
    <div className="screen no-tabs" style={{ minHeight: '100dvh', justifyContent: 'center' }}>
      <div className="auth-hero">
        <img src="/icon.svg" width={104} height={104} alt="" />
        <span className="auth-kicker">Sistema de evolução · 66 dias</span>
        <h1 className="auth-word">FORJA</h1>
        <p className="muted center">Evolua na vida real. Seu personagem evolui junto.</p>
      </div>

      <div className="card stack">
        <div className="choice-grid" role="tablist">
          <button className="choice center" role="tab" aria-pressed={mode === 'entrar'} onClick={() => setMode('entrar')}>Entrar</button>
          <button className="choice center" role="tab" aria-pressed={mode === 'criar'} onClick={() => setMode('criar')}>Criar conta</button>
        </div>
        <form className="stack" onSubmit={submit}>
          {mode === 'criar' && (
            <div className="field">
              <label htmlFor="name">Como quer ser chamado?</label>
              <input id="name" className="input" value={name} onChange={(e) => setName(e.target.value)} maxLength={40} autoComplete="nickname" required />
            </div>
          )}
          <div className="field">
            <label htmlFor="email">E-mail</label>
            <input id="email" className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" inputMode="email" required />
          </div>
          <div className="field">
            <label htmlFor="password">Senha</label>
            <input id="password" className="input" type="password" value={password} onChange={(e) => setPassword(e.target.value)}
                   autoComplete={mode === 'criar' ? 'new-password' : 'current-password'} minLength={6} required />
          </div>
          {error && <p role="alert" style={{ color: 'var(--danger)' }} className="small">{error}</p>}
          {info && <p role="status" style={{ color: 'var(--ok)' }} className="small">{info}</p>}
          <button className="btn primary block" disabled={busy}>
            {busy ? 'Aguarde…' : mode === 'criar' ? 'Criar conta' : 'Entrar'}
          </button>
          {mode === 'entrar' && <button type="button" className="link center" onClick={resetPassword}>Esqueci minha senha</button>}
        </form>
      </div>
    </div>
  );
}
