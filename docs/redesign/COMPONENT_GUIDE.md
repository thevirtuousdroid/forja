# Forja · Guia de componentes do redesign

Tudo continua com as mesmas propriedades de antes: o redesign trocou o desenho, não a forma de usar.

| Componente | Arquivo | Propriedades | Notas |
|---|---|---|---|
| `Avatar` | `components/Avatar.tsx` | `config`, `size`, `preview`, `locked`, `label` | Mesmo `AvatarConfig` e os mesmos espaços (`cabeca`, `corpo`, `capa`, `arma`, `amuleto`, `moldura`). `preview` mostra um item no lugar do equipado (inventário). Ids internos únicos por avatar. |
| `BossArt` | `components/BossArt.tsx` | `id`, `size`, `damage`, `locked`, `defeated` | Arte WebP com máscara circular; rachaduras em SVG por faixa de dano (0, 1, 2, 3) e quebra na derrota. |
| `Badge` | `components/Badge.tsx` | `category`, `rarity`, `locked`, `hidden`, `size` | Chassi octogonal com metal da raridade, marcas no topo (1 a 4), energia (raro em diante) e raios (lendário). Oculta e bloqueada mostra "?". |
| `Emblem` | `components/Emblem.tsx` | `level`, `size`, `showLevel` | Reator da forja; ganha peças nas faixas de nível 4, 8, 15 e 25. |
| `RewardOverlay` | `components/RewardOverlay.tsx` | — | Chapa com feixe de luz (`Beam`) na cor da raridade; nível mostra o emblema ao lado do número. |
| Classes de interface | `styles.css` | `.card`, `.btn`, `.bar`, `.hp`, `.check`, `.pill`, `.overlay`, `.reward`, `.beam`, `.auth-hero` | O bloco "Redesign · Cyberforge Industrial" no fim do arquivo sobrepõe o visual antigo; remover o bloco volta ao visual anterior. |

## Regras

- Alvos de toque com pelo menos 44 px.
- Cores sempre por token (`var(--accent)` etc.), nunca valores soltos em telas.
- Animações novas dentro de `@media (prefers-reduced-motion: reduce)` com alternativa parada.
- Imagens novas em WebP, até 50 KB.
