"""Prévia em Python da montagem (a página faz o mesmo em JavaScript): paleta, contornos, luz de borda e luzes suaves."""
import json, sys
import numpy as np
from PIL import Image, ImageFilter

def hx(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)

FIXED = {
    'C': ['#0a0f15', '#121a23', '#1b2733', '#283a4a', '#3d5569'],
    'D': ['#101419', '#1b2129', '#2a323c', '#404a56', '#5f6b78'],
    'M': ['#1e242d', '#38424e', '#596777', '#8595a7', '#bccad8'],
    'O': ['#6e260c', '#b8441a', '#ff7138', '#ffb45e', '#fff0d6'],
    'T': ['#0d4f55', '#13838a', '#39d5d0', '#8ff0ea', '#e6fffd'],
    'R': ['#24160f', '#3a2418', '#553624', '#714a32', '#8f6446'],
    'W': ['#8d949c', '#b9bec4', '#dadde1', '#f0f2f4', '#ffffff'],
    'K': ['#140d10', '#2a1c1e', '#3d2a2c', '#55403f', '#6e5654'],
}
SKINS = {
    'clara':   ['#8a5440', '#b8765c', '#dd9f80', '#f2c4a4', '#fde3cc'],
    'rosada':  ['#7a4630', '#a86444', '#cf8a62', '#e8b08a', '#f6d0b0'],
    'morena':  ['#5e3320', '#8a4e30', '#b06c45', '#cd8e62', '#e2b08a'],
    'escura':  ['#3a2016', '#5a3322', '#7c4a30', '#9a6444', '#b8825e'],
    'retinta': ['#22120c', '#381f15', '#523020', '#6c4330', '#8a5c46'],
}
HAIRS = {
    'preto':     ['#0b0b10', '#16161e', '#22222d', '#343444', '#4e4e62'],
    'castanho':  ['#1e120c', '#33201a', '#4c3024', '#6a4430', '#8a5c40'],
    'mel':       ['#4a2a10', '#714016', '#9a5c1e', '#c3802e', '#e2a64a'],
    'ruivo':     ['#4a1408', '#76220c', '#a83414', '#d04e1e', '#f07a3a'],
    'loiro':     ['#6a4c1e', '#9a7430', '#c49e48', '#e2c46a', '#f6e2a0'],
    'grisalho':  ['#3a3e46', '#5c626c', '#868c96', '#b4bac2', '#e0e4ea'],
    'ciano':     ['#0a3a44', '#0f5c66', '#178c92', '#3cc4c2', '#9af0e6'],
    'magenta':   ['#3e0c2e', '#661448', '#962068', '#c83a8c', '#f07ab8'],
}
EYES = {
    'castanho': ['#2a1508', '#4a2810', '#6e4020', '#9a6234', '#c48a54'],
    'mel':      ['#4a2c08', '#7a4c10', '#a8721e', '#d09c3a', '#f0c464'],
    'verde':    ['#0e2a14', '#1c4a24', '#2e6e36', '#4a9a4e', '#7ac470'],
    'azul':     ['#0c1e3a', '#183a66', '#285c96', '#4a86c4', '#86b8ec'],
    'cinza':    ['#262c34', '#3e4650', '#5e6874', '#86909c', '#b4bcc6'],
    'ciano':    ['#063c40', '#0a6a70', '#16a6a8', '#39d5d0', '#a8fff6'],
}
ORDER = ['cabelo_tras', 'martelo', 'corpo', 'armadura', 'cabeca', 'rosto', 'cabelo', 'elmo']


def palette(skin, hair, eye):
    p = {k: [hx(c) for c in v] for k, v in FIXED.items()}
    p['S'] = [hx(c) for c in SKINS[skin]]
    p['H'] = [hx(c) for c in HAIRS[hair]]
    p['I'] = [hx(c) for c in EYES[eye]]
    red = hx('#b3404a')
    p['L'] = [c * 0.55 + red * 0.45 for c in p['S']]
    return p


def decode(s):
    return [(s[i], int(s[i + 1])) if s[i] != '.' else None for i in range(0, len(s), 2)]


def compose(layers, names, pal, w=64, h=64):
    img = np.zeros((h, w, 4))
    owner = np.full((h, w), -1)
    for li, n in enumerate(names):
        cells = decode(layers[n]['px'])
        m = np.array([c is not None for c in cells]).reshape(h, w)
        for i, c in enumerate(cells):
            if c is None:
                continue
            y, x = divmod(i, w)
            lvl = c[1]
            # contorno interno: borda da camada (baixo/esquerda/direita) sobre outra camada fica um tom mais escura
            for dy, dx in ((1, 0), (0, -1), (0, 1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and not m[yy, xx] and img[yy, xx, 3] > 0:
                    lvl = max(0, lvl - 1)
                    break
            img[y, x, :3] = pal[c[0]][lvl]
            img[y, x, 3] = 1
            owner[y, x] = li
    filled = img[..., 3] > 0
    out = img.copy()
    ink = hx('#070b12')
    for y in range(h):
        for x in range(w):
            if filled[y, x]:
                continue
            nb = [(y + dy, x + dx) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)) if 0 <= y + dy < h and 0 <= x + dx < w and filled[y + dy, x + dx]]
            if nb:
                c = np.mean([img[a, b, :3] for a, b in nb], axis=0)
                out[y, x, :3] = c * 0.28 + ink * 0.72
                out[y, x, 3] = 1
    # luz de borda: ciano à direita, brasa à esquerda e embaixo
    cyan, ember = hx('#39d5d0'), hx('#ff7138')
    for y in range(h):
        for x in range(w):
            if not filled[y, x]:
                continue
            if x + 1 < w and not filled[y, x + 1]:
                out[y, x, :3] = out[y, x, :3] * 0.55 + cyan * 0.45
            elif x - 1 >= 0 and not filled[y, x - 1] and y > 28:
                out[y, x, :3] = out[y, x, :3] * 0.72 + ember * 0.28
    return out


def lights(base, scale):
    """Luzes suaves por cima dos pixels (como nas luzes dinâmicas de Children of Morta)."""
    h, w = base.shape[:2]
    big = Image.fromarray(np.uint8(np.clip(base, 0, 1) * 255) if base.max() <= 1 else np.uint8(base)).resize((w * scale, h * scale), Image.NEAREST)
    return big


def to_image(rgba, scale=6, bg='#0b1016', glow=True):
    h, w = rgba.shape[:2]
    a = rgba[..., 3:4]
    rgb = rgba[..., :3]
    bgc = hx(bg)
    # fundo com brilho da forja embaixo e neon à direita
    yy, xx = np.mgrid[0:h * scale, 0:w * scale] / scale
    ground = np.exp(-(((xx - 32) / 22) ** 2 + ((yy - 64) / 9) ** 2)) * 0.55
    neon = np.exp(-(((xx - 66) / 14) ** 2 + ((yy - 26) / 22) ** 2)) * 0.28
    canvas = np.ones((h * scale, w * scale, 3)) * bgc
    canvas += ground[..., None] * (hx('#ff7138') - bgc) * 0.6 + neon[..., None] * (hx('#39d5d0') - bgc) * 0.5
    # sombra no chão
    sh = np.exp(-(((xx - 32) / 13) ** 2 + ((yy - 61.5) / 1.8) ** 2)) * 0.7
    canvas *= (1 - sh[..., None])
    up = np.kron(rgb, np.ones((scale, scale, 1)))
    ua = np.kron(a, np.ones((scale, scale, 1)))
    canvas = canvas * (1 - ua) + up * ua
    if glow:
        # pontos que emitem luz (brasa e ciano bem claros) ganham um halo suave
        lum = np.zeros((h, w, 3))
        for c in ('#ffb45e', '#fff0d6', '#e6fffd', '#8ff0ea', '#ff7138'):
            mm = np.all(np.abs(rgb - hx(c)) < 6, axis=-1) & (a[..., 0] > 0)
            lum[mm] = hx(c)
        L = Image.fromarray(np.uint8(np.kron(lum, np.ones((scale, scale, 1))))).filter(ImageFilter.GaussianBlur(scale * 2.2))
        canvas = 255 - (255 - canvas) * (255 - np.asarray(L, float) * 0.9) / 255
    return Image.fromarray(np.uint8(np.clip(canvas, 0, 255)))


if __name__ == '__main__':
    layers = json.load(open(sys.argv[1]))
    combos = [
        dict(g='m', skin='retinta', hair='preto', eye='castanho', style='curto', items=[]),
        dict(g='m', skin='clara', hair='castanho', eye='azul', style='curto', items=['armadura', 'martelo']),
        dict(g='f', skin='escura', hair='preto', eye='mel', style='cacheado', items=[]),
        dict(g='f', skin='clara', hair='ruivo', eye='verde', style='longo', items=['elmo', 'armadura', 'martelo']),
    ]
    tiles = []
    for c in combos:
        pal = palette(c['skin'], c['hair'], c['eye'])
        names = []
        for slot in ORDER:
            if slot == 'cabelo_tras': n = f"cabelo_{c['style']}_tras"
            elif slot == 'cabelo': n = f"cabelo_{c['style']}"
            elif slot in ('corpo', 'cabeca', 'rosto'): n = f"{slot}_{c['g']}"
            elif slot == 'armadura': n = f"armadura_{c['g']}" if 'armadura' in c['items'] else None
            else: n = slot if slot in c['items'] else None
            if n: names.append(n)
        img = compose(layers, names, pal)
        tiles.append(to_image(img * np.array([255, 255, 255, 1.0]) if False else np.dstack([img[..., :3], img[..., 3]]), 6))
    W = Image.new('RGB', (len(tiles) * 390, 384), '#000')
    for i, t in enumerate(tiles):
        W.paste(t, (i * 390, 0))
    W.save(sys.argv[2])
    print('ok')
