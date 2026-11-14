# Forja · Sistema de marca "Cyberforge Industrial"

Direção visual do redesign: uma forja futurista. Metal escuro, chapas com cantos chanfrados, brasa laranja como energia principal e um ciano técnico para informação. Neutro em gênero, sem 3D, leve no celular.

## Cores (tokens em `web/src/styles.css`, `:root`)

| Token | Valor | Uso |
|---|---|---|
| `--bg` | `#080C10` | Fundo do app |
| `--surface` / `--surface-2` / `--surface-3` | `#111820` / `#1B2630` / `#263442` | Chapas, campos, níveis de profundidade |
| `--line` / `--line-hi` | `#30414D` / `#4A6070` | Bordas e divisões |
| `--text` / `--text-2` / `--text-3` | `#ECF2F5` / `#A1AFBA` / `#8494A0` | Texto principal, secundário e de apoio |
| `--accent` | `#FF7138` | Brasa: ações principais, progresso, destaque |
| `--accent-2` | `#FFB45E` | Brilho da brasa: números, XP |
| `--accent-ink` | `#1A0B04` | Texto sobre botões laranja |
| `--tech` | `#39D5D0` | Informação técnica, rótulos de sistema, foco |
| `--ok` / `--warn` / `--danger` | `#4FD18B` / `#F5C451` / `#FF5D6C` | Estados |
| Raridade | comum `#B8C4CC` · raro `#5FB4FF` · épico `#B08CFF` · lendário `#FFBF5E` | Itens, insígnias e títulos |

Contraste medido (WCAG): texto principal ≥ 13,6:1, texto secundário ≥ 6,8:1, texto de apoio ≥ 4,9:1 sobre qualquer chapa; laranja sobre fundo 7,2:1; texto escuro sobre botão laranja 7,0:1.

## Tipografia

| Papel | Fonte | Onde |
|---|---|---|
| Display | Space Grotesk 600–700 | Títulos, números grandes, marca "FORJA" |
| Texto | Inter 400–600 | Corpo, botões, campos |
| Sistema | IBM Plex Mono 500 | Rótulos em maiúsculas, XP, contadores, etiquetas |

Rótulos de seção: mono, maiúsculas, espaçamento 0,14–0,18em, com uma barra laranja curta à esquerda.

## Formas

- **Chapa:** cantos chanfrados com `clip-path` (`--cut: 10px`), borda fina `--line`, brilho laranja no topo das chapas de destaque.
- **Octógono:** insígnias, ícone do app, emblema, botão de concluir missão.
- **Barras segmentadas:** XP, vida do chefe e progresso são divididos em blocos, como um medidor de máquina.

## Movimento

- Concluir missão: o octógono "acende" (animação `ignite`).
- Recompensas: feixe de luz girando atrás da arte, na cor da raridade, e faíscas.
- Personagem e chefes: sem animação contínua pesada; tudo respeita `prefers-reduced-motion`.

## Ícone do app

Chama sobre a bigorna dentro de uma placa octogonal de aço, com uma linha ciano no topo da bigorna (`web/public/icon.svg`, PNGs de 512, 192 e 180 px).
