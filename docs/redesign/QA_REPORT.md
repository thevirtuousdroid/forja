# Forja · Relatório de qualidade do redesign

_13/11/2026 · branch `redesign` (versão 0.6.0), ainda não publicado._

## O que foi verificado

| Verificação | Resultado |
|---|---|
| Verificação de tipos (TypeScript) | ✅ sem erros |
| Testes do app (Vitest) | ✅ 46 de 46 |
| Build de produção | ✅ |
| Telas no navegador, tamanho de iPhone (390×844), contra banco local com a conta de teste veterana | ✅ 32 telas sem nenhum erro de página |
| Telas de recompensa (vitória, conquista, temporada, nível, título) | ✅ conferidas uma a uma |
| Backend, migrações SQL, RPCs, XP e dados | ✅ nenhum arquivo de `supabase/` alterado em relação ao `main` |
| Contraste (WCAG AA 4,5:1) | ✅ todos os pares de texto; `--text-3` ajustado de `#74838F` para `#8494A0` (era 3,9:1 nas chapas mais claras) |
| Inventário com prévia do item no personagem | ✅ preservado |
| Todos os 27 equipamentos mudam o desenho do personagem | ✅ coberto por teste |
| Ids internos dos desenhos não colidem com vários avatares na mesma tela | ✅ coberto por teste |

## Peso

| Arquivo | Antes (main 0.5.1) | Depois | Diferença |
|---|---|---|---|
| CSS | 24,8 KB (5,7 KB gzip) | 34,1 KB (7,5 KB gzip) | +1,8 KB gzip |
| JS do app | 294,1 KB (82,2 KB gzip) | 306,6 KB (90,3 KB gzip) | +8,1 KB gzip |
| Artes dos chefes | — | cerca de 49 KB em 7 WebP | carregadas só nas telas de chefe |
| Fontes | 1 família | 3 famílias (Google Fonts) | em cache depois do primeiro acesso |

## Pendências conhecidas

1. **Chefes em 200 px.** Ficam um pouco suaves na tela de batalha. Trocar pelas versões grandes quando forem baixadas.
2. **Personagem gerado por IA.** Decidido e testado, em pausa (ver `ASSET_MANIFEST.md`). A versão desenhada está ativa até lá.
3. **Peças sobrepostas no personagem por IA** (capa com armadura, capuz com elmo) ainda não testadas juntas.
4. **Publicação.** Juntar `redesign` no `main` só com aprovação; nada do banco precisa rodar para esta versão.
