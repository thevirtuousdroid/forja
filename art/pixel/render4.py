"""Prévia da direção cyberpunk: contorno neon ciano (direita) e magenta (esquerda), luz da cidade ao fundo."""
import json, sys
import numpy as np
from PIL import Image, ImageFilter
import render, render3
from render import hx, decode

SHOULDER = render3.SHOULDER
COAT_MAT = {'cap_curta': 'C', 'cap_constante': 'V', 'cap_fenix': 'F', 'cap_mestre': 'D'}


def order(c, layers, blink=False):
    g, e = c['corpo'], c.get('equip', {})
    s = render3.STYLES[c['cabelo']]
    cab, cor, cap, arm, amu = e.get('cabeca'), e.get('corpo'), e.get('capa'), e.get('arma'), e.get('amuleto')
    pose = 'ombro' if arm in SHOULDER else 'solto'
    sleeve = 'J' if cor == 'cor_gibao' else COAT_MAT.get(cap)
    out = []
    if cap: out.append(f'{cap}_tras_{g}')
    if not (cab in render3.HIDE_BACK and s in ('coque', 'volumoso')) and cab not in ('cab_capuz', 'cab_elmo_ferro'):
        out.append(f'cabelo_{s}_tras_{g}')
    if arm in SHOULDER: out.append(f'{arm}_tras_{g}')
    out += [f'pescoco_{g}', f'corpo_{g}', f'cyber_{g}', f'detalhe_{g}', f'luva_esq_{g}']
    if arm and arm not in SHOULDER: out.append(f'{arm}_tras_{g}')
    out.append(f'braco_ombro_{g}' if pose == 'ombro' else f'braco_{g}')
    if pose == 'solto': out.append(f'luva_solto_{g}')
    if sleeve: out += [f'manga_{sleeve}_esq_{g}', f'manga_{sleeve}_{pose}_{g}']
    if cor and cor != 'cor_tunica': out.append(f'{cor}_{g}')
    if amu: out.append(f'{amu}_{g}')
    if cap: out.append(f'{cap}_{g}')
    if pose == 'ombro':
        out.append(f'antebraco_ombro_{g}')
        if sleeve: out.append(f'manga_{sleeve}_ombro_ante_{g}')
        out += [f'{arm}_{g}', f'mao_ombro_{g}', f'luva_ombro_{g}']
    out += [f'cabeca_{g}', f'implante_{g}', f'rosto_{g}_piscar' if blink else f'rosto_{g}']
    if c.get('barba'): out.append(f"barba_{c['barba']}_{g}")
    if cab not in ('cab_capuz', 'cab_elmo_ferro'): out.append(f'cabelo_{s}_{g}')
    if cab: out.append(f'{cab}_{g}')
    return [n for n in out if n in layers]


def compose(layers, names, pal, w=None, h=None):
    w = h = int(round((len(layers[names[0]]['px']) / 2) ** 0.5))
    img = np.zeros((h, w, 4))
    for n in names:
        cells = decode(layers[n]['px'])
        m = np.array([cc is not None for cc in cells]).reshape(h, w)
        for i, cc in enumerate(cells):
            if cc is None: continue
            y, x = divmod(i, w); lvl = cc[1]
            for dy, dx in ((1, 0), (0, -1), (0, 1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and not m[yy, xx] and img[yy, xx, 3] > 0:
                    lvl = max(0, lvl - 1); break
            img[y, x, :3] = pal[cc[0]][lvl]; img[y, x, 3] = 1
    filled = img[..., 3] > 0
    out = img.copy(); ink = hx('#070b12')
    cyan, mag = hx('#39d5d0'), hx('#ff3fa8')
    for y in range(h):
        for x in range(w):
            if filled[y, x]: continue
            nb = [(y + dy, x + dx) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)) if 0 <= y + dy < h and 0 <= x + dx < w and filled[y + dy, x + dx]]
            if nb:
                cm = np.mean([img[a, b, :3] for a, b in nb], axis=0)
                out[y, x, :3] = cm * 0.28 + ink * 0.72; out[y, x, 3] = 1
    for y in range(h):
        for x in range(w):
            if not filled[y, x]: continue
            if x + 1 < w and not filled[y, x + 1]:
                out[y, x, :3] = out[y, x, :3] * 0.5 + cyan * 0.5
            elif x - 1 >= 0 and not filled[y, x - 1]:
                out[y, x, :3] = out[y, x, :3] * 0.55 + mag * 0.45
    return out


def image(rgba, scale=4, bg='#0a0d16'):
    h, w = rgba.shape[:2]
    unit = h / 96
    a = rgba[..., 3:4]; rgb = rgba[..., :3]; bgc = hx(bg)
    yy, xx = np.mgrid[0:h * scale, 0:w * scale] / (scale * unit)
    canvas = np.ones((h * scale, w * scale, 3)) * bgc
    canvas += (np.exp(-(((xx + 4) / 22) ** 2 + ((yy - 40) / 40) ** 2)) * 0.5)[..., None] * (hx('#ff3fa8') - bgc) * 0.45
    canvas += (np.exp(-(((xx - 100) / 22) ** 2 + ((yy - 40) / 40) ** 2)) * 0.5)[..., None] * (hx('#39d5d0') - bgc) * 0.45
    canvas += (np.exp(-(((xx - 48) / 30) ** 2 + ((yy - 98) / 10) ** 2)) * 0.4)[..., None] * (hx('#ff7138') - bgc) * 0.5
    # cidade ao fundo: prédios escuros com janelas acesas
    rng = np.random.default_rng(3)
    for k in range(9):
        bx0 = int(rng.integers(0, 88)); bw = int(rng.integers(6, 14)); bh = int(rng.integers(20, 55))
        k_ = scale * unit
        x0, x1, y0 = int(bx0 * k_), int((bx0 + bw) * k_), int((96 - bh) * k_)
        canvas[y0:, x0:x1] = canvas[y0:, x0:x1] * 0.55 + hx('#0e1420') * 0.45
        for _ in range(bw * bh // 25):
            wx = int(int(rng.integers(bx0 + 1, bx0 + bw - 1)) * k_); wy = int(int(rng.integers(96 - bh + 2, 92)) * k_)
            col = hx('#ff3fa8') if rng.random() < 0.3 else hx('#39d5d0') if rng.random() < 0.5 else hx('#ffb45e')
            kk = int(k_)
            canvas[wy:wy + kk, wx:wx + kk] = canvas[wy:wy + kk, wx:wx + kk] * 0.7 + col * 0.18
    canvas *= (1 - (np.exp(-(((xx - 48) / 16) ** 2 + ((yy - 92) / 2.2) ** 2)) * 0.7)[..., None])
    up = np.kron(rgb, np.ones((scale, scale, 1))); ua = np.kron(a, np.ones((scale, scale, 1)))
    canvas = canvas * (1 - ua) + up * ua
    lum = np.zeros((h, w, 3))
    for cc in ('#ffb45e', '#fff0d6', '#e6fffd', '#8ff0ea', '#ff9ad8', '#e040a8'):
        mm = np.all(np.abs(rgb - hx(cc)) < 8, axis=-1) & (a[..., 0] > 0); lum[mm] = hx(cc)
    L = Image.fromarray(np.uint8(np.kron(lum, np.ones((scale, scale, 1))))).filter(ImageFilter.GaussianBlur(scale * unit * 2.5))
    canvas = 255 - (255 - canvas) * (255 - np.asarray(L, float) * 0.9) / 255
    return Image.fromarray(np.uint8(np.clip(canvas, 0, 255)))


if __name__ == '__main__':
    layers = json.load(open(sys.argv[1]))
    combos = [
        dict(corpo='m', pele=4, cabelo=0, corCabelo=0, corRoupa=4, barba=1, olhos='ciano', equip=dict(corpo='cor_gibao', arma='arm_lamina')),
        dict(corpo='f', pele=1, cabelo=4, corCabelo=7, corRoupa=3, barba=0, olhos='verde', equip=dict(capa='cap_mestre', cabeca='cab_coroa', arma='arm_martelo')),
        dict(corpo='m', pele=2, cabelo=1, corCabelo=1, corRoupa=0, barba=0, olhos='castanho', equip=dict(cabeca='cab_elmo_ferro', corpo='cor_placas', arma='arm_martelo')),
        dict(corpo='f', pele=5, cabelo=5, corCabelo=5, corRoupa=4, barba=0, olhos='mel', equip=dict(cabeca='cab_capuz', capa='cap_constante', arma='arm_lamina')),
    ]
    tiles = []
    for c in combos:
        pal = render3.palette(c)
        tiles.append(image(compose(layers, order(c, layers), pal), 2))
    # recorte alto: o personagem ocupa o quadro
    tiles = [t.crop((22 * 4, 0, 74 * 4, 384)) for t in tiles]
    W = Image.new('RGB', (len(tiles) * 212, 384), '#000')
    for i, t in enumerate(tiles): W.paste(t, (i * 212, 0))
    W.save(sys.argv[2]); print('ok')
