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
            lift = 1 if 0.2 < t < 0.85 else 0      # sobe do nariz, pico a 2/3, cai na ponta
            if 0.45 < t < 0.75:
                lift = 2 if fem else 1
            if t > 0.95:
                lift = 0
            P(X, by - 1 - lift, 'H', 1)
            if t < (0.25 if fem else 0.55):
                P(X, by - lift, 'H', 0)
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


def head_v3(r):
    """Cabeça com formato de rosto humano: testa redonda, maçãs na altura dos olhos e
    maxilar que afina em curva até um queixo arredondado (mais estreito na mulher)."""
    from engine import Hi, SCALE as S
    L = Part()
    hx, hy, rx, ry = r['head']
    fem = r['female']
    cy = r['chin'][1] + 0.4
    cw = 2.3 if fem else 3.1          # meia-largura do queixo
    p = 1.25 if fem else 1.7          # quanto o maxilar segura a largura antes de afinar
    top = hy - ry
    yc = hy + 1.5                     # linha mais larga (maçãs do rosto)
    M = np.zeros((L.h, L.w), bool)
    for Y in range(L.h):
        y = (Y + 0.5) / S
        if y < top or y > cy:
            continue
        if y <= yc:
            w = (rx + 0.1) * np.sqrt(max(0.0, 1 - ((yc - y) / (yc - top)) ** 2))
        else:
            t = (y - yc) / (cy - yc)
            w = cw + (rx + 0.1 - cw) * (1 - t ** p)
            rr = 1.6                  # arredonda a ponta do queixo
            if y > cy - rr:
                w = min(w, cw * np.sqrt(max(0.0, 1 - ((y - (cy - rr)) / rr) ** 2)) + 0.3)
        xs = (np.arange(L.w) + 0.5) / S
        M[Y] = np.abs(xs - hx) <= w
    face = Hi(M)
    for ex in (hx - rx + 0.1, hx + rx - 0.1):   # orelhas
        L.part(); ell(L, ex, hy + 2.0, 1.4, 2.4, 'S', bias=-0.5, spread=2.4, dither=0.16)
    L.part(); L.ellipsoid(face, hx - 0.6, hy, rx + 0.6, ry + 1.6, 'S', bias=0.15, spread=2.5, dither=0.18)
    # sombra suave sob a maçã do rosto (lado da sombra) e luz na maçã do lado da luz
    V = raw(L.lvl); Mt = raw(L.mat)
    for Y in range(int((hy + 4) * S), int((hy + 6.5) * S)):
        for X in range(int((hx + rx - 2.6) * S), int((hx + rx - 0.6) * S)):
            if Mt[Y, X] == 'S' and (X + Y) % 2 == 0 and V[Y, X] > 0:
                V[Y, X] -= 1
    # sombra embaixo do queixo
    for X in range(L.w):
        col = np.where(M[:, X])[0]
        if len(col):
            V[col[-1], X] = max(0, V[col[-1], X] - 1)
    L.seams()
    # sombra que o queixo projeta no pescoço: separa o rosto do pescoço
    nr = r['neck'][2] + 0.6
    for X in range(L.w):
        x = (X + 0.5) / S
        if abs(x - hx) > nr:
            continue
        col = np.where(M[:, X])[0]
        y0 = col[-1] + 1 if len(col) else int(cy * S)
        depth = int(round((2.4 - 1.2 * (abs(x - hx) / nr) ** 2) * S))
        for Y in range(y0, min(L.h, y0 + depth)):
            Mt[Y, X] = 'S'
            V[Y, X] = 0 if Y - y0 < depth * 0.6 or (X + Y) % 2 else 1
    return L


# ── cabelos cacheados (novos): cachos definidos e tranças ───────────────────

def _ball(L, cx, cy, rx, ry, bias=0.0, mat='H'):
    """Um cacho: bolinha sombreada no pixel fino, com borda escura."""
    from engine import SCALE as S, LIGHT
    M = raw(L.mat); V = raw(L.lvl)
    X0, X1 = int((cx - rx) * S) - 1, int((cx + rx) * S) + 2
    Y0, Y1 = int((cy - ry) * S) - 1, int((cy + ry) * S) + 2
    for Y in range(max(0, Y0), min(L.h, Y1)):
        for X in range(max(0, X0), min(L.w, X1)):
            nx = ((X + 0.5) / S - cx) / rx; ny = ((Y + 0.5) / S - cy) / ry
            d = nx * nx + ny * ny
            if d > 1:
                continue
            nz = np.sqrt(max(0.02, 1 - d))
            l = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
            v = int(np.clip(round(1.2 + 2.6 * l + bias), 0, 4))
            if d > 0.72:
                v = max(0, v - 1)
            M[Y, X] = mat; V[Y, X] = v


def curls_defined(r):
    """Cachos definidos na altura dos ombros, repartidos de lado, emoldurando o rosto."""
    front, back = Part(), Part()
    hx, hy, rx, ry = r['head']
    rng = np.random.default_rng(21)
    # massa de trás (escura) para não ficar buraco entre os cachos
    base = back.mask_ellipse(hx, hy - 1.5, rx + 3.4, ry + 0.6) | back.mask_poly(
        [(hx - rx - 3.6, hy), (hx + rx + 3.6, hy), (hx + rx + 3.0, hy + 9.5), (hx - rx - 3.0, hy + 9.5)])
    back.flat(base, 'H', 0)
    pts = []
    for y in np.arange(hy - ry - 0.4, hy + 10.5, 1.9):
        for x in np.arange(hx - rx - 3.6, hx + rx + 3.8, 2.1):
            x_ = x + (0.9 if int((y - hy) / 1.9) % 2 else 0) + rng.uniform(-0.3, 0.3)
            if raw(base)[int(y * 2), int(np.clip(x_ * 2, 0, 191))]:
                pts.append((x_, y + rng.uniform(-0.3, 0.3)))
    for (x, y) in sorted(pts, key=lambda p: p[1]):
        _ball(back, x, y, 1.35, 1.25, bias=-0.6 - 0.04 * (y - hy))
    # frente: topo da cabeça + cachos na testa + colunas dos lados do rosto
    cap = front.mask_ellipse(hx + 0.4, hy - 2.6, rx + 1.6, ry - 0.8)
    cap[int(hy - 3.4):, :] = False
    front.ellipsoid(cap, hx - 2, hy - 6, rx + 2, ry, 'H', bias=-0.2, spread=2.4, dither=0.1)
    tops = []
    for y in np.arange(hy - ry + 0.2, hy - 3.6, 1.8):
        for x in np.arange(hx - rx - 1.0, hx + rx + 1.6, 2.0):
            x_ = x + (1.0 if int((y - hy) / 1.8) % 2 else 0) + rng.uniform(-0.25, 0.25)
            if raw(cap)[int(y * 2), int(x_ * 2)]:
                tops.append((x_, y))
    for x in np.arange(hx - rx + 0.2, hx + rx + 0.4, 2.0):   # franja de cachos, mais volume no lado da risca
        tops.append((x + rng.uniform(-0.2, 0.2), hy - 3.4 + (0.6 if x > hx + 1 else 0)))
    for (x, y) in sorted(tops, key=lambda p: p[1]):
        _ball(front, x, y, 1.3, 1.2, bias=0.15)
    for side in (-1, 1):                                       # colunas que caem ao lado do rosto
        for k, y in enumerate(np.arange(hy - 2.2, hy + 9.0, 1.8)):
            x = hx + side * (rx + 0.6 + 0.12 * k) + (0.5 if k % 2 else -0.2) * side
            _ball(front, x, y, 1.3, 1.15, bias=0.0 - 0.05 * k)
    return front, back


def _braid(L, x0, y0, x1, y1, w=1.5, cuff=True):
    """Trança: faixa com padrão de gomos em V; ponta com anel de neon."""
    from engine import SCALE as S
    M = raw(L.mat); V = raw(L.lvl)
    ax, ay, bx, by = x0 * S, y0 * S, x1 * S, y1 * S
    dx, dy = bx - ax, by - ay
    ln = np.hypot(dx, dy); ux, uy = dx / ln, dy / ln
    hw = w * S / 2
    for Y in range(max(0, int(min(ay, by) - hw) - 1), min(L.h, int(max(ay, by) + hw) + 2)):
        for X in range(max(0, int(min(ax, bx) - hw) - 1), min(L.w, int(max(ax, bx) + hw) + 2)):
            px_, py_ = X + 0.5 - ax, Y + 0.5 - ay
            s = px_ * ux + py_ * uy
            u = -px_ * uy + py_ * ux
            if s < 0 or s > ln or abs(u) > hw:
                continue
            if cuff and s > ln - 3:
                M[Y, X] = 'T'; V[Y, X] = 4 if s < ln - 1.5 else 3
                continue
            ph = (s - 1.4 * abs(u)) % 4
            v = 4 if ph < 1.5 else 2 if ph < 3 else 0
            if u > hw - 1:
                v = max(0, v - 1)               # lado da sombra
            if s > ln - 5 and cuff:
                v = max(0, v - 1)
            M[Y, X] = 'H'; V[Y, X] = v


def braids(r):
    """Tranças finas (box braids) com anéis de neon nas pontas; frente com risca no couro."""
    front, back = Part(), Part()
    hx, hy, rx, ry = r['head']
    rng = np.random.default_rng(8)
    scalp = back.mask_ellipse(hx, hy - 1.2, rx + 1.2, ry + 0.2)
    back.flat(scalp, 'H', 0)
    xs = np.arange(hx - rx - 1.4, hx + rx + 1.6, 1.25)
    for x in xs:                              # tranças de trás, abrindo para os lados
        t = (x - hx) / (rx + 1.4)
        top_y = hy - ry * np.sqrt(max(0.05, 1 - min(1, t * t))) + 1.0
        x_end = x + t * 2.6
        _braid(back, x, top_y, x_end, hy + 15.5 + rng.uniform(-1.5, 1.5), 1.5, cuff=rng.random() < 0.45)
    cap = front.mask_ellipse(hx, hy - 1.6, rx + 0.8, ry - 0.3)
    cap[int(hy - 3.0):, :] = False
    sidem = front.mask_poly([(hx - rx - 0.8, hy - 4), (hx - rx + 1.2, hy - 4), (hx - rx + 0.9, hy + 0.2), (hx - rx - 0.4, hy + 0.2)])
    capm = cap | sidem | sidem[:, ::-1]
    front.ellipsoid(capm, hx - 1.5, hy - 4.5, rx + 1.2, ry, 'H', bias=0.1, spread=2.6, dither=0.1)
    M = raw(front.mat); V = raw(front.lvl)
    for X in range(M.shape[1]):               # linha do cabelo em arco (mais alta no meio)
        t = ((X + 0.5) / 2 - hx) / (rx + 0.8)
        if abs(t) > 1:
            continue
        yl = hy - 3.0 - 1.0 * (1 - t * t)
        for Y in range(int(yl * 2), int((hy - 2.9) * 2) + 1):
            if M[Y, X] == 'H' and abs(t) < 0.8:
                M[Y, X] = ''
    for Y in range(M.shape[0]):               # divisões quadradas das tranças (box braids)
        for X in range(M.shape[1]):
            if M[Y, X] == 'H':
                row = (Y + 1) // 5
                if (X + (row % 2) * 3) % 6 == 0 or (Y + 1) % 5 == 0:
                    V[Y, X] = 0
                elif (X + (row % 2) * 3) % 6 == 1 and V[Y, X] < 4:
                    V[Y, X] += 1
    for side in (-1, 1):                      # duas tranças caindo na frente dos ombros
        for j in range(2):
            x0 = hx + side * (rx - 0.2 + j * 1.2)
            _braid(front, x0, hy - 3.2, x0 + side * (1.6 + j * 0.8), hy + 13.5 - j * 1.5, 1.5, cuff=True)
    return front, back


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
        put(f'cabeca_{g}', head_v3(r), 'head')
        fr, bk = curls_defined(r)
        put(f'cabelo_cacheado_{g}', fr, 'head'); put(f'cabelo_cacheado_tras_{g}', bk, 'head')
        fr, bk = braids(r)
        put(f'cabelo_volumoso_{g}', fr, 'head'); put(f'cabelo_volumoso_tras_{g}', bk, 'head')
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
