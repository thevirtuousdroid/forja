import base64, json
ids=[('tempestade','A Tempestade Interna','Guardiã da Sobrecarga','#6FA8FF'),('adiador','O Adiador','Chefe da Procrastinação','#E0A23C'),
     ('hidra','A Hidra das Notificações','Guardiã das Distrações','#39D5D0'),('nevoa','A Névoa do Esquecimento','Guardiã do Esquecimento','#B9A8F0'),
     ('sentinela','A Sentinela de Pedra','Sentinela do Desconforto','#4FD1B0'),('errante','O Errante','Mestre da Inconsistência','#A18AFF'),
     ('juiz','O Juiz da Bigorna','Desafio da Disciplina','#FF7138')]
data=[dict(id=i,name=n,ep=e,color=c,src='data:image/png;base64,'+base64.b64encode(open(f'{i}_q128.png','rb').read()).decode()) for i,n,e,c in ids]
html='''<title>Chefes em Pixel</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
:root{--bg:#070a12;--panel:#0d121d;--line:#1d2636;--fg:#e8edf5;--mute:#8592a6;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font-family:'Space Grotesk',system-ui,sans-serif}
main{max-width:1000px;margin:0 auto;padding-block:20px 40px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
h1{font-size:22px;margin:0 0 4px;letter-spacing:.02em}
.sub{color:var(--mute);font:12px 'JetBrains Mono',monospace;margin:0 0 18px;line-height:1.5}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px}
.card{background:var(--panel);border:1px solid var(--line);overflow:hidden;clip-path:polygon(0 0,calc(100% - 14px) 0,100% 14px,100% 100%,14px 100%,0 calc(100% - 14px))}
canvas{display:block;width:100%;aspect-ratio:1;image-rendering:pixelated;background:#0a0d16}
.meta{padding:10px 12px 12px;border-top:1px solid var(--line)}
.meta b{display:block;font-size:15px}
.meta span{font:11px 'JetBrains Mono',monospace;letter-spacing:.06em;text-transform:uppercase}
.bar{display:flex;gap:8px;margin:0 0 16px;flex-wrap:wrap}
button{background:#121a28;color:var(--fg);border:1px solid var(--line);font:600 12px 'JetBrains Mono',monospace;padding:8px 12px;border-radius:3px;cursor:pointer}
button[aria-pressed=true]{border-color:#39d5d0;color:#8ff0ea}
</style>
<main>
<h1>Chefes da Forja · pixel art</h1>
<p class="sub">Gerados por IA no estilo Children of Morta cyberpunk e convertidos para pixel de verdade (128 px, 40 cores). As luzes pulsam.</p>
<div class="bar"><button id="b0" aria-pressed="true">Batalha</button><button id="b1" aria-pressed="false">Ferido</button><button id="b2" aria-pressed="false">Derrotado</button><button id="b3" aria-pressed="false">Bloqueado</button></div>
<div class="grid" id="g"></div>
</main>
<script>
const B = __DATA__, N = 128;
let mode = 0, f = 0;
const g = document.getElementById('g'), cards = [];
for (const b of B) {
  const el = document.createElement('div'); el.className = 'card';
  el.innerHTML = `<canvas width="${N}" height="${N}"></canvas><div class="meta"><b></b><span></span></div>`;
  el.querySelector('b').textContent = b.name; const sp = el.querySelector('span'); sp.textContent = b.ep; sp.style.color = b.color;
  g.appendChild(el);
  const c = { b, ctx: el.querySelector('canvas').getContext('2d'), base: null };
  const img = new Image(); img.onload = () => { const t = document.createElement('canvas'); t.width = t.height = N; const x = t.getContext('2d'); x.drawImage(img, 0, 0); c.base = x.getImageData(0, 0, N, N); c.glow = mask(c.base); draw(); }; img.src = b.src;
  cards.push(c);
}
function mask(im) { // pixels acesos: claros e saturados
  const d = im.data, m = new Uint8Array(N * N);
  for (let i = 0; i < N * N; i++) { const r = d[i*4], gg = d[i*4+1], bb = d[i*4+2], mx = Math.max(r, gg, bb), mn = Math.min(r, gg, bb); if (mx > 140 && mx - mn > 70) m[i] = 1; }
  return m;
}
['b0','b1','b2','b3'].forEach((id, i) => document.getElementById(id).onclick = () => { mode = i; document.querySelectorAll('.bar button').forEach((x, j) => x.setAttribute('aria-pressed', j === i)); draw(); });
const CR = [[[40,34],[46,44],[42,52],[50,60],[47,70]], [[84,30],[78,42],[85,50],[79,62]], [[58,66],[64,76],[59,84],[66,92]]];
function draw() {
  for (const c of cards) {
    if (!c.base) continue;
    const out = new ImageData(new Uint8ClampedArray(c.base.data), N, N), d = out.data;
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const i = y * N + x, k = i * 4;
      let w = 1;
      if (c.glow[i] && mode < 2) w = 0.8 + 0.25 * Math.sin(f * 0.8 + x * 0.3 + y * 0.2) + 0.07 * Math.sin(f * 2.3 + x);
      let r = d[k] * w, gg = d[k+1] * w, bb = d[k+2] * w;
      if (mode === 2) { const l = (r + gg + bb) / 3 * 0.55; r = gg = bb = l; }
      if (mode === 3) { const l = (r + gg + bb) / 3; r = gg = bb = l > 40 ? 14 : l * 0.3; }
      d[k] = r; d[k+1] = gg; d[k+2] = bb;
    }
    if (mode === 1) for (let s = 0; s < CR.length; s++) { const p = CR[s];
      for (let j = 0; j < p.length - 1; j++) { const [x0,y0] = p[j], [x1,y1] = p[j+1], n = Math.max(Math.abs(x1-x0), Math.abs(y1-y0));
        for (let t = 0; t <= n; t++) { const x = Math.round(x0 + (x1-x0)*t/n), y = Math.round(y0 + (y1-y0)*t/n), k = (y*N+x)*4, hot = (t + f) % 5;
          d.set(hot ? [255,180,94] : [255,240,214], k); if (x+1 < N) d.set([255,113,56], k+4); } } }
    if (mode === 2) { // partido ao meio
      const cp = new Uint8ClampedArray(d);
      for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) { const k = (y*N+x)*4, cut = 64 + Math.round(Math.sin(y * 0.4) * 2);
        const sx = x < cut ? x + 3 : x - 3, sy = x < cut ? y - 2 : y + 1;
        if (sx < 0 || sx >= N || sy < 0 || sy >= N || Math.abs(x - cut) < 2) { d.set([10,13,22], k); continue; }
        d.set(cp.subarray((sy*N+sx)*4, (sy*N+sx)*4+3), k); } }
    c.ctx.putImageData(out, 0, 0);
  }
}
setInterval(() => { f++; if (mode < 2) draw(); }, 140);
</script>'''.replace('__DATA__', json.dumps(data))
open('bosses.html','w').write(html)
print('ok', len(html))
