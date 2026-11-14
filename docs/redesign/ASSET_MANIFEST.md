# Forja · Inventário de arte do redesign

| Arte | Arquivo | Formato | Peso | Origem | Situação |
|---|---|---|---|---|---|
| Hidra das Notificações | `web/src/assets/bosses/hidra.webp` | WebP 200 px | 10 KB | IA (Canva), opção 2 | Falta versão grande |
| Tempestade Interna | `.../tempestade.webp` | WebP 200 px | 9,5 KB | IA (Canva) | Falta versão grande |
| O Adiador | `.../adiador.webp` | WebP 200 px | 6,6 KB | IA (Canva) | Falta versão grande |
| Névoa do Esquecimento | `.../nevoa.webp` | WebP 200 px | 2,6 KB | IA (Canva), versão 1 | Falta versão grande |
| Sentinela de Pedra | `.../sentinela.webp` | WebP 200 px | 8,3 KB | IA (Canva) | Falta versão grande |
| O Errante | `.../errante.webp` | WebP 200 px | 2,9 KB | IA (Canva) | Falta versão grande |
| Juiz da Bigorna | `.../juiz.webp` | WebP 200 px | 8,3 KB | IA (Canva) | Falta versão grande |
| Rachaduras de dano | `BossArt.tsx` | SVG no código | — | Desenho próprio | Pronto |
| Personagem e 27 equipamentos | `Avatar.tsx` | SVG no código | — | Desenho próprio | Pronto (versão desenhada) |
| 58 insígnias (11 categorias × 4 raridades) | `Badge.tsx` | SVG no código | — | Desenho próprio | Pronto |
| Emblema de nível (5 faixas) | `Emblem.tsx` | SVG no código | — | Desenho próprio | Pronto |
| Ícone do app | `web/public/icon.svg` + PNGs | SVG/PNG | 115 KB (512 px) | Desenho próprio | Pronto |

Total das artes dos chefes: cerca de 49 KB, abaixo do limite de 50 KB por imagem pedido.

## Personagem gerado por IA (em pausa)

Decidido e testado, mas não integrado. 4 personagens-base na mesma pose (Canva): homem negro `MAHa11D19ls`, homem branco `MAHa15QGWPw`, mulher negra `MAHa1-LjMIw`, mulher branca `MAHa164UoL4`. Cabelo, barba e equipamentos gerados em cima de cada base e recortados por diferença; cor do cabelo pintada pelo app. Estimativa: cerca de 115 imagens. Depende de:

1. baixar as imagens em tamanho grande (liberar `media.canva.com` nas Capacidades do claude.ai, ou baixar à mão);
2. uma pequena migração para o banco guardar o personagem-base e a cor dos olhos (`update_avatar` hoje só guarda pele, cabelo, corCabelo, barba e corRoupa).
