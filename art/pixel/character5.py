"""Forja · cyberpunk com mais detalhe e superfícies limpas.

1) Menos granulado: o dithering de todas as formas cai para 35% (superfícies limpas, brilhos definidos).
2) Camada de detalhes: zíper com puxador, recortes do traje nas pernas, cinto com bolsinhos,
   luvas sem dedo, botas com tiras e biqueira, costuras.
Gera layers5.json.
"""
import json, sys
import numpy as np
import engine

_orig_quant = engine.Layer._quant
engine.Layer._quant = lambda self, l, bias, spread, dither=0.35: _orig_quant(self, l, bias, spread, dither * 0.35)

import character3 as c3  # noqa: E402  (depois do ajuste do dithering)
from character2 import N, Part, RIG, mirror, ell, grip  # noqa: E402

KW = dict(spread=2.9, dither=0.1)


def details(r):
    L = Part()
    fem = r['female']
    # zíper central com puxador
    for y in range(30, 46):
        L.px(48, y, 'M', 3 if y % 2 else 1)
    L.part(); ell(L, 48.5, 33.5, 0.9, 1.4, 'M', bias=0.6, **KW)
    # recortes do traje nas pernas (painel na lateral da coxa e costura do joelho)
    for side in (0, 1):
        f = (lambda p: p) if side == 0 else mirror
        (a, b, r0, r1) = r['thigh']
        a, b = f(a), f(b)
        off = -1 if side == 0 else 1
        for t in np.linspace(0.1, 0.92, 14):
            x = int(round(a[0] + (b[0] - a[0]) * t + off * (r0 + (r1 - r0) * t) * 0.55)); y = int(round(a[1] + (b[1] - a[1]) * t))
            L.px(x, y, 'C', 0)
        kx, ky = f(r['thigh'][1])
        for dx in range(-2, 3):
            L.px(int(kx + dx), int(ky + 3), 'C', 0)
        (a, b, r0, r1) = r['shin']
        a, b = f(a), f(b)
        for t in np.linspace(0.05, 0.6, 5):  # dobra da calça sobre a bota
            x = int(round(a[0] + (b[0] - a[0]) * t - off * 1.2)); y = int(round(a[1] + (b[1] - a[1]) * t))
            L.px(x, y, 'C', 4)
    # cinto com bolsinhos e fivela
    for (x0, x1) in ((40.5, 43.5), (52.5, 55.5)) if not fem else ((41.5, 44), (52, 54.5)):
        pouch = L.mask_poly([(x0, 46.6), (x1, 46.6), (x1, 50.2), (x0, 50.2)])
        L.part(); L.cylinder(pouch, 'D', bias=0.25, **KW)
        for x in range(int(x0), int(x1) + 1):
            L.px(x, 46, 'D', 3)
        L.px(int((x0 + x1) / 2), 48, 'M', 4)
    buckle = L.mask_poly([(46.4, 46.4), (49.6, 46.4), (49.6, 48.6), (46.4, 48.6)])
    L.part(); L.cylinder(buckle, 'M', bias=0.4, **KW)
    L.px(47, 47, 'O', 4); L.px(48, 47, 'O', 4)
    # botas: biqueira e tiras
    for side in (0, 1):
        fx, fy, frx, fry = r['foot']
        fx = fx if side == 0 else 96 - fx
        toe = L.mask_ellipse(fx + (-1.2 if side == 0 else 1.2), fy + 0.2, frx * 0.55, fry * 0.8)
        L.part(); L.ellipsoid(toe, fx - 1.6, fy - 0.6, frx * 0.6, fry, 'M', bias=0.2, **KW)
        ex = r['shin'][1][0] if side == 0 else 96 - r['shin'][1][0]
        for yy in (82, 85):
            for x in range(int(ex - 3), int(ex + 4)):
                L.px(x, yy, 'D', 4 if x == int(ex - 2) else 0)
            L.px(int(ex + 2), yy, 'M', 4)  # fivela da tira
    L.seams()
    return L


def glove(cx, cy, rx, ry):
    """Luva sem dedo: costas da mão escuras, nós dos dedos com placa, dedos de fora."""
    L = Part()
    back = L.mask_ellipse(cx, cy - ry * 0.25, rx + 0.3, ry * 0.75)
    L.part(); L.ellipsoid(back, cx - 0.6, cy - ry * 0.5, rx + 0.4, ry, 'J', bias=0.2, **KW)
    for dx in (-1, 0, 1):
        L.px(int(round(cx + dx)), int(round(cy + ry * 0.3)), 'M', 3)
    L.px(int(round(cx)), int(round(cy - ry * 0.6)), 'T', 3)
    L.seams()
    return L


def build():
    l3 = c3.build()
    json.dump(l3, open('layers3.json', 'w'), separators=(',', ':'))
    import character4 as c4
    layers = c4.build()
    def put(name, L, part):
        if L is not None and (L.mat != '').any():
            layers[name] = dict(px=L.encode(), part=part)
    for g, r in RIG.items():
        put(f'detalhe_{g}', details(r), 'body')
        hx_, hy_, hrx, hry = r['hand']
        put(f'luva_esq_{g}', glove(hx_, hy_, hrx, hry), 'body')
        put(f'luva_solto_{g}', glove(96 - hx_, hy_, hrx, hry), 'body')
        _, hand, _, _ = grip(r)
        put(f'luva_ombro_{g}', glove(hand[0], hand[1], hrx + 0.3, hry - 0.4), 'body')
    return layers


if __name__ == '__main__':
    out = build()
    json.dump(out, open(sys.argv[1], 'w'), separators=(',', ':'))
    print(len(out), 'camadas')
