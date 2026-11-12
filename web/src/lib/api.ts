// Escolhe a versão do app na hora do build:
//   VITE_BACKEND=supabase → versão com servidor, para várias pessoas (padrão)
//   VITE_BACKEND=local    → versão individual: sem login, dados no espaço privado da pessoa (build:pagina)
import { api as remoteApi } from './api.remote';
import { localApi } from './api.local';
export { friendlyError } from './errors';

export const BACKEND: 'local' | 'supabase' = import.meta.env.VITE_BACKEND === 'local' ? 'local' : 'supabase';
export const api = BACKEND === 'local' ? localApi : remoteApi;
export { localApi };
