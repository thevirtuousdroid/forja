# Pixel art do Forja (teste aprovado em 14/11/2026)

Estilo: pixel art com luz forte e brilho suave por cima (referência de técnica: Children of Morta), no visual cyberpunk de forja.

- `engine.py`: motor de desenho (formas com volume, luz direcional, dithering, membros afunilados).
- `character2.py`: personagem 96x96 em camadas (2 corpos, cabeça, rosto e piscar, 3 cabelos, armadura, elmo, braço solto ou segurando a marreta no ombro). Gera `layers2.json`.
- `boss.py`: a Hidra das Notificações 96x96 em 4 quadros.
- `render.py` / `render2.py`: paletas trocáveis (pele, cabelo, olhos) e a montagem com contornos coloridos e luz de borda; prévias em PNG.
- `page_tpl.html`: página de teste (o mesmo motor de montagem em JavaScript).

Gerar: `python3 character2.py layers2.json && python3 render2.py layers2.json previa.png`
