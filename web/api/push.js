// Função da Vercel chamada pelo banco (pg_net) para enviar um lote de notificações.
// Usa as mesmas variáveis do app (VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY): não há segredo extra.
// O pedido só traz um código de uso único; sem um código válido, o banco não entrega nada.
import { processBatch, supabaseRpc } from '../server/push.js';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY;

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    res.status(405).json({ error: 'use POST' });
    return;
  }
  let body = null;
  try { body = req.body; } catch { body = null; }   // JSON malformado: a Vercel lança ao ler
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch { body = null; } }
  const token = body && typeof body.token === 'string' ? body.token : '';
  if (!/^[0-9a-f]{64}$/.test(token)) {
    res.status(400).json({ error: 'token' });
    return;
  }
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    res.status(500).json({ error: 'faltam VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY' });
    return;
  }
  try {
    const out = await processBatch(token, { rpc: supabaseRpc(SUPABASE_URL, SUPABASE_KEY) });
    res.status(200).json(out);
  } catch (e) {
    const status = e && e.status && e.status < 500 ? 404 : 502;
    res.status(status).json({ error: String((e && e.message) || e) });
  }
}
