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
from engine import raw  # noqa: E402

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
    # cadarços e sola com cravos (pixel fino)
    for side in (0, 1):
        ex = r['shin'][1][0] if side == 0 else 96 - r['shin'][1][0]
        for yy in np.arange(80.5, 88, 1.0):
            L.px1(ex - 0.5, yy, 'W', 2 if int(yy * 2) % 2 else 1)
            L.px1(ex + 0.5, yy + 0.5, 'W', 2)
        fx, fy, frx, fry = r['foot']
        fx = fx if side == 0 else 96 - fx
        for xx in np.arange(fx - frx + 0.5, fx + frx, 1.0):
            L.px1(xx, 90.5, 'D', 0)
    # costura pespontada ao lado do zíper
    for yy in np.arange(30.5, 46, 1.0):
        L.px1(47 if int(yy * 2) % 2 else 49.5, yy, 'C', 4)
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


def strands(layer, seed=1):
    """Fios de cabelo: linhas finas mais claras e mais escuras seguindo o comprimento."""
    M = raw(layer.mat); V = raw(layer.lvl)
    rng = np.random.default_rng(seed)
    hm = M == 'H'
    if not hm.any():
        return
    ys, xs = np.where(hm)
    for x in range(xs.min(), xs.max() + 1, 3):
        col = np.where(hm[:, x])[0]
        if len(col) < 4:
            continue
        ph = int(rng.integers(0, 6))
        for y in col:
            k = (y + ph) % 9
            if k == 0 and V[y, x] < 4:
                V[y, x] += 1
            elif k == 4 and V[y, x] > 0:
                V[y, x] -= 1


def fine_face(r):
    """Olhos e boca no pixel fino: íris com brilho, linha dos cílios, contorno dos lábios."""
    L = Part()
    y = r['eye_y']
    for xs in ((43, 44, 45, 46), (50, 51, 52, 53)):
        x0 = xs[0]
        for k in range(8):  # linha dos cílios, 1 pixel fino, levemente curva
            L.px1(x0 + k * 0.5, y - 0.5 - (0.5 if 2 <= k <= 5 else 0), 'K', 0)
        L.px1(xs[1] + 0.5, y + 0.5, 'K', 0)   # pupila
        L.px1(xs[1], y, 'W', 4)                # brilho na íris
        L.px1(xs[2], y + 1, 'I', 3)            # aro inferior claro
    my = y + 6
    for k in range(6):
        L.px1(46.5 + k * 0.5, my + 0.5, 'S', 0) if not r['female'] else L.px1(46.5 + k * 0.5, my + 0.5, 'L', 0)
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


def face_hi(r, blink=False):
    """Rosto desenhado no pixel fino (192): olhos com cílios, íris redonda, pupila e brilho; sobrancelha afinada;
    nariz com ponte e narinas; boca com linha e lábio. Coordenadas em pixels finos (x2)."""
    L = Part()
    P = lambda X, Y, m, v: L.px1(X / 2, Y / 2, m, v)
    fem = r['female']
    ey = r['eye_y'] * 2 + 1          # linha do meio dos olhos (fino)
    for side in (-1, 1):
        cx = 96 + side * 7            # centro de cada olho (fino); 96 = meio do rosto
        if blink:
            for k in range(-3, 4):
                P(cx + k, ey + (1 if abs(k) < 3 else 0), 'K', 1)
            continue
        # branco do olho (7x3) com cantos recortados
        for k in range(-3, 4):
            for dy in (-1, 0, 1):
                if abs(k) == 3 and dy != 0:
                    continue
                P(cx + k, ey + dy, 'W', 3 if dy < 1 else 2)
        # íris redonda 3x3, pupila e brilho
        ix = cx + (-side * 0)         # olhando para frente
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                P(ix + dx, ey + dy, 'I', 1 if dy == 1 else 3 if dy == -1 else 2)
        P(ix, ey, 'K', 0); P(ix, ey - 1, 'K', 1)
        P(ix - 1, ey - 1, 'W', 4)
        # pálpebra de cima e cílios
        for k in range(-4, 5):
            P(cx + k, ey - 2 - (1 if abs(k) <= 2 else 0), 'K', 0)
        if fem:
            P(cx + side * 5, ey - 3, 'K', 0); P(cx + side * 6, ey - 4, 'K', 0); P(cx + side * 4, ey - 4, 'K', 0)
        # sombra da pálpebra de baixo
        for k in range(-2, 3):
            P(cx + k, ey + 2, 'S', 1)
        # sobrancelha afinada (2 px de altura no meio, 1 nas pontas)
        by = ey - 6 - (1 if fem else 0)
        for k in range(-5, 6):
            t = (k * side + 5) / 10            # 0 perto do nariz, 1 na ponta de fora
            yy = by - (int(round(np.sin(t * np.pi) * (2 if fem else 1))))
            P(cx + k, yy, 'H', 1)
            if (not fem and t < 0.8) or (fem and 0.2 < t < 0.6):
                P(cx + k, yy + 1, 'H', 0)
    # nariz: ponte com luz, ponta, narinas
    for Y in range(ey - 2, ey + 6):
        P(96 - 1, Y, 'S', 4 if Y < ey + 3 else 3)
    P(95, ey + 7, 'S', 4)
    P(93, ey + 8, 'S', 0); P(98, ey + 8, 'S', 0)
    for X in range(94, 99):
        P(X, ey + 9, 'S', 1)
    # boca
    my = ey + 12 + (1 if fem else 0)
    lip = 'L' if fem else 'S'
    for X in range(91, 101):
        P(X, my, lip, 0 if X in (91, 100) else 1)
    for X in range(93, 99):
        P(X, my + 1, lip, 3 if fem else 2)
        P(X, my + 2, lip, 2 if fem else 1)
    P(95, my - 1, lip, 2); P(96, my - 1, lip, 2)
    return L


def stubble_hi(r):
    """Barba por fazer: pontilhado fino e esparso."""
    L = Part()
    hx, hy, rx, ry = r['head']
    cw, cy = r['chin']
    m = L.mask_poly([(hx - rx + 0.4, hy + 0.5), (hx + rx - 0.4, hy + 0.5), (hx + rx - 1.4, hy + 5.5), (hx + cw + 0.5, cy),
                     (hx - cw - 0.5, cy), (hx - rx + 1.4, hy + 5.5)])
    m &= ~L.mask_poly([(hx - rx + 2, hy - 2), (hx + rx - 2, hy - 2), (hx + rx - 2.5, r['eye_y'] + 4), (hx - rx + 2.5, r['eye_y'] + 4)])
    ys, xs = np.where(raw(m))
    rng = np.random.default_rng(4)
    for y, x in zip(ys, xs):
        if rng.random() < 0.2:
            L.px1(x / 2, y / 2, 'H', 1 if rng.random() < 0.6 else 2)
    return L


def face_v3(r, blink=False):
    """Rosto no pixel fino mantendo as proporções do desenho anterior: olho amendoado de 2 linhas
    (sem branco grande), íris 4px com pupila e brilho, pálpebra fina, nariz só por sombra, boca curta."""
    L = Part()
    P = lambda X, Y, m, v: L.px1(X / 2, Y / 2, m, v)
    fem = r['female']
    ey = r['eye_y'] * 2               # linha de cima da abertura do olho (fino)
    for x0, side in ((86, -1), (100, 1)):   # x0 = canto esquerdo de cada olho (8 px finos de largura)
        out = x0 if side < 0 else x0 + 7    # canto de fora
        inn = x0 + 7 if side < 0 else x0
        if blink:
            for k in range(8):
                P(x0 + k, ey + 1, 'K', 1)
            P(out, ey + 2, 'K', 1)
        else:
            # pálpebra de cima: linha escura, desce no canto de fora (amendoado)
            ic = x0 + 3 + (1 if side < 0 else 0)   # íris levemente puxada para o nariz
            for k in range(8):
                X = x0 + k
                P(X, ey - (2 if ic - 2 <= X < ic + 2 else 1), 'K', 0)
            P(out, ey, 'K', 0)
            if fem:
                P(out + side, ey - 1, 'K', 0); P(out + side, ey - 2, 'K', 0); P(out, ey - 2, 'K', 1)
            # abertura: 2 linhas; branco só nas pontas
            for k in range(8):
                X = x0 + k
                if X == out:
                    continue
                for dy in (0, 1):
                    P(X, ey + dy, 'W', 3 if dy == 0 else 2)
            for X in range(ic - 2, ic + 2):
                P(X, ey - 1, 'I', 1)
                P(X, ey, 'I', 2)
                P(X, ey + 1, 'I', 3)
            P(ic - 1, ey, 'K', 0); P(ic, ey, 'K', 0)     # pupila
            P(ic - 1, ey - 1, 'K', 0); P(ic, ey - 1, 'K', 1)
            P(ic - 2, ey - 1, 'W', 4)                   # brilho
            # pálpebra de baixo: sombra suave
            for k in range(1, 7):
                P(x0 + k, ey + 2, 'S', 1)
        # sobrancelha: 2 px no começo, afina para fora, leve arco
        by = ey - 5 - (1 if fem else 0)
        for k in range(-1, 9):
            X = x0 + k
            t = (X - inn) * (-side) / 9.0 if side < 0 else (X - inn) / 9.0
            t = abs((X - inn) / 9.0)
            lift = 1 if 0.25 < t < 0.75 else 0
            if fem and 0.35 < t < 0.65:
                lift = 2
            P(X, by - lift, 'H', 1)
            if t < (0.5 if fem else 0.8):
                P(X, by - lift + 1, 'H', 0)
    # nariz: sombra de um lado, ponta com luz, narinas
    nx = 96
    for Y in range(ey + 2, ey + 7):
        P(nx - 2, Y, 'S', 1 if Y > ey + 3 else 2)
    P(nx - 1, ey + 7, 'S', 4); P(nx, ey + 7, 'S', 4)
    P(nx - 3, ey + 8, 'S', 1); P(nx - 2, ey + 9, 'S', 0); P(nx + 1, ey + 9, 'S', 0)
    for X in range(nx - 1, nx + 1):
        P(X, ey + 9, 'S', 1)
    # boca
    my = ey + 13
    if fem:
        for X in range(nx - 4, nx + 4):
            P(X, my, 'L', 0 if X in (nx - 4, nx + 3) else 1)
        for X in range(nx - 3, nx + 3):
            P(X, my + 1, 'L', 3)
        for X in range(nx - 2, nx + 2):
            P(X, my + 2, 'L', 2)
        P(nx - 1, my - 1, 'L', 2); P(nx, my - 1, 'L', 2)
    else:
        P(nx - 4, my, 'S', 1); P(nx + 3, my, 'S', 1)
        for X in range(nx - 3, nx + 3):
            P(X, my, 'S', 0)
        for X in range(nx - 2, nx + 2):
            P(X, my + 1, 'S', 3)
        P(nx - 1, my + 3, 'S', 1); P(nx, my + 3, 'S', 1)   # sombra sob o lábio
    return L


def stubble_v3(r):
    """Barba por fazer: sombra de pele no maxilar + fios finos esparsos (sem mancha no bigode)."""
    L = Part()
    hx, hy, rx, ry = r['head']
    cw, cy = r['chin']
    m = L.mask_poly([(hx - rx + 0.4, hy + 0.5), (hx + rx - 0.4, hy + 0.5), (hx + rx - 1.4, hy + 5.5), (hx + cw + 0.5, cy),
                     (hx - cw - 0.5, cy), (hx - rx + 1.4, hy + 5.5)])
    m &= ~L.mask_poly([(hx - rx + 2, hy - 2), (hx + rx - 2, hy - 2), (hx + rx - 2.5, r['eye_y'] + 4.5), (hx - rx + 2.5, r['eye_y'] + 4.5)])
    ys, xs = np.where(raw(m))
    ey = r['eye_y'] * 2
    rng = np.random.default_rng(7)
    for y, x in zip(ys, xs):
        if ey + 12 <= y <= ey + 14 and 90 <= x <= 101:   # deixa a boca limpa
            continue
        if (x + y) % 2 == 0:
            L.px1(x / 2, y / 2, 'S', 1)
        elif rng.random() < 0.18:
            L.px1(x / 2, y / 2, 'H', 1)
    return L


def build():
    l3 = c3.build()
    json.dump(l3, open('layers3.json', 'w'), separators=(',', ':'))
    import character4 as c4
    layers = c4.build()
    def put(name, L, part):
        if L is not None and (L.mat != '').any():
            layers[name] = dict(px=L.encode(), part=part)
    for k, v in list(layers.items()):  # fios em todos os cabelos e barbas
        if k.startswith('cabelo_') or k.startswith('barba_'):
            from engine import Layer as _L
            tmp = Part()
            M = raw(tmp.mat); V = raw(tmp.lvl)
            px = v['px']; n = tmp.w
            for i in range(0, len(px), 2):
                if px[i] != '.':
                    M[(i // 2) // n, (i // 2) % n] = px[i]; V[(i // 2) // n, (i // 2) % n] = int(px[i + 1])
            strands(tmp, seed=len(k))
            layers[k] = dict(px=tmp.encode(), part=v['part'])
    for g, r in RIG.items():
        put(f'detalhe_{g}', details(r), 'body')
        put(f'rosto_{g}', face_v3(r), 'head')
        put(f'rosto_{g}_piscar', face_v3(r, True), 'head')
        put(f'barba_1_{g}', stubble_v3(r), 'head')
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
