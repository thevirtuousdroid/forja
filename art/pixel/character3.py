"""Forja · pixel art completo do personagem (96x96): 8 cabelos, barbas e os 27 equipamentos.

Reaproveita o corpo aprovado (character2) e acrescenta o resto. Gera layers3.json.
Materiais novos: B aço azul · G pedra-verde · Y ouro · V tecido roxo · F tecido rubi
"""
import json, sys
import numpy as np
from engine import Layer
from character2 import (N, Part, RIG, mirror, ell, body, head, face, hair as hair_v2, armor as plates, helmet as iron_helm,
                        grip, right_arm, hammer_shoulder)

KW = dict(spread=2.8, dither=0.16)


# ── cabelos ─────────────────────────────────────────────────────────────────

def hair(style, r):
    hx, hy, rx, ry = r['head']
    if style in ('curto', 'longo'):
        return hair_v2(style, r)
    if style == 'volumoso':
        return hair_v2('cacheado', r)
    front, back = Part(), Part()
    if style == 'raspado':
        m = front.mask_ellipse(hx, hy - 1.6, rx + 0.5, ry - 0.2)
        m[int(hy - 3.2):, :] = False
        side = front.mask_poly([(hx - rx - 0.5, hy - 4), (hx - rx + 1.5, hy - 4), (hx - rx + 1.2, hy + 0.5), (hx - rx, hy + 0.5)])
        m = m | side | side[:, ::-1]
        front.ellipsoid(m, hx - 1.5, hy - 4, rx + 1, ry, 'H', bias=-0.2, spread=2.0, dither=0.55)
    elif style == 'franja':
        cap = front.mask_ellipse(hx, hy - 2.4, rx + 1.6, ry - 0.5)
        cap[int(hy - 2.4):, :] = False
        bangs = front.mask_poly([(hx - rx - 0.4, hy - 6), (hx + rx + 0.4, hy - 6), (hx + rx - 0.6, hy - 2.2), (hx - rx + 0.6, hy - 2.2)])
        bob = front.mask_poly([(hx - rx - 1.8, hy - 4), (hx - rx + 1.6, hy - 3), (hx - rx + 1.4, hy + 7), (hx - rx - 1.6, hy + 7.5)])
        m = cap | bangs | bob | bob[:, ::-1]
        front.ellipsoid(m, hx - 1.5, hy - 3, rx + 2.5, ry + 3, 'H', bias=0.2, spread=2.7, **{'dither': 0.14})
        for x in range(int(hx - rx), int(hx + rx + 1), 2):
            front.px(x, int(hy - 3), 'H', 1)
        for (x, y) in [(hx - 4, hy - 8), (hx - 3, hy - 9), (hx + 3, hy - 8), (hx - 2, hy - 5), (hx - rx - 1, hy + 2)]:
            front.px(int(x), int(y), 'H', 4)
        bk = back.mask_poly([(hx - rx - 1.8, hy - 4), (hx + rx + 1.8, hy - 4), (hx + rx + 1.8, hy + 7.5), (hx - rx - 1.8, hy + 7.5)])
        back.cylinder(bk, 'H', bias=-1.0, spread=2.0, dither=0.14)
    elif style == 'cacheado':
        rng = np.random.default_rng(5)
        bk = back.mask_ellipse(hx, hy + 0.5, rx + 3.6, ry + 2.4)
        back.ellipsoid(bk, hx - 2, hy - 3, rx + 4, ry + 3, 'H', bias=-0.6, spread=2.4, dither=0.16)
        top = front.mask_ellipse(hx, hy - 3.6, rx + 2.8, ry - 1.6)
        top[int(hy - 2.6):, :] = False
        for cx_ in (hx - 4.5, hx - 1.5, hx + 1.5, hx + 4.5):  # cachinhos caindo na testa
            top |= front.mask_ellipse(cx_, hy - 2.6, 1.6, 1.4)
        front.ellipsoid(top, hx - 2, hy - 6, rx + 3, ry, 'H', bias=0.15, spread=2.6, dither=0.16)
        for layer, msk, n in ((back, bk, 120), (front, top, 70)):
            for _ in range(n):
                y, x = rng.integers(0, N, 2)
                if msk[y, x] and x + 1 < N and y + 1 < N and msk[y, x + 1]:
                    lv = layer.lvl[y, x]
                    layer.px(x, y, 'H', min(4, lv + 1))
                    if msk[y + 1, x + 1]:
                        layer.px(x + 1, y + 1, 'H', max(0, lv - 2))
    elif style == 'coque':
        cap = front.mask_ellipse(hx, hy - 1.2, rx + 0.9, ry - 0.9)
        cap[int(hy - 2.8):, :] = False
        side = front.mask_poly([(hx - rx - 0.6, hy - 4), (hx - rx + 1.8, hy - 4), (hx - rx + 1.4, hy + 1), (hx - rx, hy + 1)])
        m = cap | side | side[:, ::-1]
        front.ellipsoid(m, hx - 1.5, hy - 4, rx + 1.5, ry, 'H', bias=0.2, spread=2.7, dither=0.14)
        for t in np.linspace(-0.8, 0.8, 7):  # fios penteados para trás
            x = int(hx + t * rx * 0.9)
            for y in range(int(hy - ry + 1.6), int(hy - 3.5), 2):
                if front.mat[y, x]:
                    front.px(x, y, 'H', 1)
        by_ = hy - ry - 2.8
        bun = back.mask_ellipse(hx + 0.3, by_, 3.9, 3.3)
        back.part(); back.ellipsoid(bun, hx - 0.9, by_ - 1.2, 4.0, 3.5, 'H', bias=0.25, spread=2.8, dither=0.08)
        for (x, y) in ((hx - 2, by_ - 1), (hx, by_ - 2), (hx + 2, by_ - 1), (hx - 1, by_ + 1), (hx + 1, by_ + 1)):
            back.px(int(x), int(y), 'H', 1)  # voltas do coque
        back.px(int(hx - 1), int(by_ - 2), 'H', 4)
        tie = back.mask_poly([(hx - 2.0, by_ + 2.6), (hx + 2.6, by_ + 2.6), (hx + 2.2, by_ + 3.8), (hx - 1.6, by_ + 3.8)])
        back.part(); back.flat(tie, 'O', 3)
        back.seams()
    # 'sem': nada
    return front, back


def beard(kind, r):
    L = Part()
    if kind == 0:
        return L
    hx, hy, rx, ry = r['head']
    cw, cy = r['chin']
    y = r['eye_y']
    my = y + 6
    jaw = L.mask_poly([(hx - rx + 0.4, hy + 0.5), (hx + rx - 0.4, hy + 0.5), (hx + rx - 1.4, hy + 5.5), (hx + cw + 0.5, cy + (1.6 if kind == 2 else 0)),
                       (hx - cw - 0.5, cy + (1.6 if kind == 2 else 0)), (hx - rx + 1.4, hy + 5.5)])
    cheeks_cut = L.mask_poly([(hx - rx + 2, hy - 2), (hx + rx - 2, hy - 2), (hx + rx - 2.5, my - 2.2), (hx - rx + 2.5, my - 2.2)])
    m = jaw & ~cheeks_cut
    if kind == 1:  # por fazer: pontilhado
        yy, xx = np.mgrid[0:N, 0:N]
        dots = m & (((xx * 3 + yy * 5) % 7) == 0)
        L.flat(dots, 'H', 2)
        for x in (46, 48, 50):
            L.px(x, my - 1, 'H', 2)
    else:  # cheia
        L.ellipsoid(m, hx - 1.5, hy + 2, rx + 0.8, ry - 1, 'H', bias=0.0, spread=2.5, dither=0.14)
        for x in range(45, 52):  # bigode
            L.px(x, my - 1, 'H', 2 if x in (45, 51) else 1)
        for x in range(46, 51):  # boca aparecendo
            L.mat[my, x] = ''
        for x in range(47, 50):
            L.mat[my + 1, x] = ''
        for (x, yy_) in [(44, my + 2), (47, my + 4), (51, my + 3), (49, int(cy))]:
            L.px(x, yy_, 'H', 3)
    return L


# ── cabeça ──────────────────────────────────────────────────────────────────

def headband(r):
    L = Part()
    hx, hy, rx, ry = r['head']
    band = L.mask_poly([(hx - rx - 0.6, hy - 5.2), (hx + rx + 0.6, hy - 5.2), (hx + rx + 0.4, hy - 2.6), (hx - rx - 0.4, hy - 2.6)])
    L.part(); L.cylinder(band, 'F', bias=0.2, **KW)
    tail = L.mask_poly([(hx + rx, hy - 4.6), (hx + rx + 4.2, hy - 1.5), (hx + rx + 3.2, hy + 1.6), (hx + rx - 0.4, hy - 2.8)])
    L.part(); L.cylinder(tail, 'F', bias=-0.4, **KW)
    L.px(int(hx - 1), int(hy - 4), 'T', 4); L.px(int(hx), int(hy - 4), 'T', 3)
    L.seams()
    return L


def hood(r):
    front, back = Part(), Part()
    hx, hy, rx, ry = r['head']
    outer = front.mask_ellipse(hx, hy - 0.6, rx + 3.2, ry + 2.4)
    inner = front.mask_ellipse(hx, hy + 1.2, rx - 0.2, ry - 0.6)
    drape = front.mask_poly([(hx - rx - 3.2, hy + 1), (hx - rx + 0.5, hy + 4), (hx - 3, hy + 13), (hx + 3, hy + 13), (hx + rx - 0.5, hy + 4),
                             (hx + rx + 3.2, hy + 1), (hx + rx + 4.6, hy + 12.5), (hx - rx - 4.6, hy + 12.5)])
    m = (outer | drape) & ~inner
    m[int(hy + 12):, :] &= drape[int(hy + 12):, :]
    front.part(); front.ellipsoid(m, hx - 2, hy - 2, rx + 5, ry + 8, 'D', bias=0.15, spread=2.6, dither=0.14)
    rim = inner & ~front.mask_ellipse(hx, hy + 1.6, rx - 1.1, ry - 1.4)
    for (yy, xx) in zip(*np.where(rim)):
        if yy < hy + 2:
            front.px(xx, yy, 'T', 3 if (xx + yy) % 3 else 4)
    for y in range(int(hy - ry - 1), int(hy - 1)):
        front.px(int(hx), y, 'D', 0)
    front.seams()
    shade = Part()  # sombra do capuz na testa
    band = shade.mask_ellipse(hx, hy - 2.2, rx - 0.4, 2.2) & inner
    return front, back


def silence_helm(r):
    L = Part()
    hx, hy, rx, ry = r['head']
    dome = L.mask_ellipse(hx, hy - 1.6, rx + 1.8, ry + 0.3)
    dome[int(hy - 2.4):, :] = False
    L.part(); L.ellipsoid(dome, hx - 2, hy - 4.4, rx + 2.2, ry + 1, 'B', bias=0.0, **KW)
    for side in (-1, 1):
        cx_ = hx + side * (rx + 0.6)
        cup = L.mask_ellipse(cx_, hy + 0.6, 3.0, 4.6)
        L.part(); L.ellipsoid(cup, cx_ - 0.8, hy - 0.4, 3.2, 4.8, 'B', bias=0.1, **KW)
        ring = L.mask_ellipse(cx_, hy + 0.6, 2.0, 3.2) & ~L.mask_ellipse(cx_, hy + 0.6, 1.0, 2.0)
        L.flat(ring, 'T', 3)
        L.px(int(cx_), int(hy + 0.6), 'T', 4)
    for x in range(int(hx - 2), int(hx + 3)):
        L.px(x, int(hy - ry - 0.6), 'B', 4)
    L.seams()
    return L


def ember_crown(r):
    L = Part()
    hx, hy, rx, ry = r['head']
    band = L.mask_poly([(hx - rx - 0.4, hy - 6.8), (hx + rx + 0.4, hy - 6.8), (hx + rx + 0.2, hy - 4.2), (hx - rx - 0.2, hy - 4.2)])
    L.part(); L.cylinder(band, 'Y', bias=0.3, **KW)
    for k, dx in enumerate((-5, -2.5, 0, 2.5, 5)):
        h = 5.5 if dx == 0 else 4 if abs(dx) < 3 else 3
        flame = L.mask_poly([(hx + dx - 1.4, hy - 6.6), (hx + dx + 1.4, hy - 6.6), (hx + dx + 0.6, hy - 6.6 - h * 0.6), (hx + dx, hy - 6.6 - h),
                             (hx + dx - 0.6, hy - 6.6 - h * 0.6)])
        L.part(); L.flat(flame, 'O', 3)
        L.px(int(hx + dx), int(hy - 6.6 - h * 0.45), 'O', 4)
    for dx in (-4, 0, 4):
        L.px(int(hx + dx), int(hy - 5.6), 'F', 3)
    L.seams()
    return L


# ── roupas (espaço "corpo") ─────────────────────────────────────────────────

def torso_mask(L, r, pad=0.0):
    if r['female']:
        pts = [(44.5, 27.5), (51.5, 27.5), (55.5, 30.8), (55.6, 35), (53.6, 43.5), (54.6, 47), (41.4, 47), (42.4, 43.5), (40.4, 35), (40.5, 30.8)]
    else:
        pts = [(44, 27), (52, 27), (57.5, 29.6), (58, 35), (55, 44), (55.6, 47), (40.4, 47), (41, 44), (38, 35), (38.5, 29.6)]
    c = np.array(pts).mean(0)
    pts = [tuple(c + (np.array(p) - c) * (1 + pad)) for p in pts]
    return L.mask_poly(pts)


def jerkin(r):
    """Gibão de couro: colete acolchoado com costuras e gola."""
    L = Part()
    m = torso_mask(L, r, 0.06)
    m &= ~L.mask_poly([(46.5, 26), (49.5, 26), (48, 36)])
    L.part(); L.cylinder(m, 'R', bias=0.0, tilt=0.4, **KW)
    for y in range(31, 46, 3):  # acolchoado
        for x in range(36, 61):
            if m[y, x]:
                L.px(x, y, 'R', max(0, L.lvl[y, x] - 1))
    for y in range(36, 46):
        L.px(48, y, 'R', 0)
    for y in range(37, 46, 2):
        L.px(47, y, 'Y', 3)
    L.seams()
    return L


def chainmail(r):
    """Cota de malha: trama de elos, com tabardo na cor da roupa por cima."""
    L = Part()
    m = torso_mask(L, r, 0.05)
    L.part(); L.cylinder(m, 'M', bias=-0.3, tilt=0.3, **KW)
    for y in range(26, 50):
        for x in range(34, 62):
            if m[y, x] and ((x + (y // 2) % 2 * 1) % 2 == 0) and y % 2 == 0:
                L.px(x, y, 'M', max(0, L.lvl[y, x] - 2))
    tab = L.mask_poly([(44.5, 31), (51.5, 31), (52.5, 50), (48, 53), (43.5, 50)])
    L.part(); L.cylinder(tab, 'C', bias=0.1, **KW)
    for y in range(32, 50):
        L.px(44 if y < 50 else 45, y, 'Y', 2) if tab[y, 44] else None
        L.px(51, y, 'Y', 2) if tab[y, 51] else None
    for (x, y) in [(48, 38), (47, 39), (49, 39), (48, 40), (48, 41)]:
        L.px(x, y, 'O', 3)
    L.seams()
    return L


def sentinel(r):
    """Peitoral da Sentinela: placas de pedra verde com circuitos ciano."""
    L = Part()
    m = torso_mask(L, r, 0.1)
    m[46:, :] = False
    L.part(); L.cylinder(m, 'G', bias=-0.1, tilt=0.5, **KW)
    for y in range(30, 46):  # linha central de circuito
        L.px(48, y, 'T', 3 if y % 4 else 4)
    for (a, b) in (((48, 34), (43, 37)), ((48, 34), (53, 37)), ((48, 40), (42, 43)), ((48, 40), (54, 43))):
        for t in np.linspace(0, 1, 7):
            x = int(round(a[0] + (b[0] - a[0]) * t)); y = int(round(a[1] + (b[1] - a[1]) * t))
            if m[y, x]:
                L.px(x, y, 'T', 3)
    for (x, y) in ((43, 37), (53, 37), (42, 43), (54, 43)):
        L.px(x, y, 'T', 4)
    for side in (0, 1):  # ombreiras angulosas de pedra
        sx, sy = r['sh'] if side == 0 else mirror(r['sh'])
        pts = [(sx - 4.6, sy + 2.2), (sx - 3, sy - 3), (sx + 3, sy - 3.6), (sx + 4.6, sy + 1.6), (sx + 1, sy + 3)]
        if side:
            pts = [(2 * sx - p[0], p[1]) for p in pts]
        L.part(); L.cylinder(L.mask_poly(pts), 'G', bias=0.1, **KW)
        L.px(int(sx), int(sy - 1), 'T', 4)
    L.seams()
    return L


# ── capas ───────────────────────────────────────────────────────────────────

CAPES = {
    'cap_curta': dict(mat='C', trim='D', length=62, lining=None),
    'cap_constante': dict(mat='V', trim='Y', length=86, lining=None),
    'cap_fenix': dict(mat='F', trim='O', length=84, lining=None),
    'cap_mestre': dict(mat='D', trim='O', length=86, lining='O'),
}


def cape(cid, r):
    cfg = CAPES[cid]
    back, front = Part(), Part()
    sl = r['sh'][0] - (r['delt'][0] + 1.2)
    sr = 96 - sl
    bottom = cfg['length']
    spread_ = 7 if bottom > 70 else 3
    pts = [(sl + 1, r['sh'][1] - 2), (sr - 1, r['sh'][1] - 2), (sr + spread_, bottom), (sl - spread_, bottom)]
    m = back.mask_poly(pts)
    back.part(); back.cylinder(m, cfg['mat'], bias=-0.7, spread=2.2, dither=0.14)
    for x in range(int(sl - spread_), int(sr + spread_) + 1, 4):  # pregas
        for y in range(int(r['sh'][1] + 8), bottom):
            if m[y, x]:
                back.px(x, y, cfg['mat'], 0)
    for x in range(int(sl - spread_), int(sr + spread_) + 1):  # barra
        for dy in (0, 1):
            y = bottom - 1 - dy
            if m[y, x]:
                back.px(x, y, cfg['trim'], 3 if dy == 0 else 2)
    if cid == 'cap_fenix':  # penas de brasa na barra
        for x in range(int(sl - spread_) + 1, int(sr + spread_), 3):
            back.px(x, bottom, 'O', 4); back.px(x, bottom + 1, 'O', 3)
            back.px(x + 1, bottom, 'O', 3)
    if cfg['lining']:
        for y in range(int(r['sh'][1] + 4), bottom - 2):
            for x in (int(sl - spread_ * (y - r['sh'][1]) / (bottom - r['sh'][1])) + 1,
                      int(sr + spread_ * (y - r['sh'][1]) / (bottom - r['sh'][1])) - 1):
                if m[y, x]:
                    back.px(x, y, 'O', 2)
    back.seams()
    # manto sobre os ombros e fecho
    for side in (0, 1):
        sx, sy = r['sh'] if side == 0 else mirror(r['sh'])
        mm = front.mask_ellipse(sx, sy - 0.6, r['delt'][0] + 1.4, 2.6)
        mm[int(sy + 1):, :] = False
        front.part(); front.ellipsoid(mm, sx - 1.2, sy - 1.6, r['delt'][0] + 1.6, 3, cfg['mat'], bias=0.1, **KW)
    collar = front.mask_poly([(sl + 2.5, r['sh'][1] - 2.6), (sr - 2.5, r['sh'][1] - 2.6), (sr - 4, r['sh'][1] - 0.6), (sl + 4, r['sh'][1] - 0.6)])
    collar &= ~front.mask_ellipse(48, 27, 6.2 if not r['female'] else 5.2, 3.2)
    front.part(); front.cylinder(collar, cfg['mat'], bias=0.2, **KW)
    for side in (-1, 1):
        cxp = 48 + side * (6.4 if not r['female'] else 5.4)
        clasp = front.mask_ellipse(cxp, r['sh'][1] - 1.0, 1.5, 1.5)
        front.part(); front.ellipsoid(clasp, cxp - 0.4, r['sh'][1] - 1.4, 1.5, 1.5, 'Y', bias=0.4, **KW)
    if cid == 'cap_mestre':
        for x in range(int(48 - 5), int(48 + 6), 2):
            front.px(x, int(r['sh'][1] - 0.2), 'M', 3)
    front.seams()
    return back, front


# ── armas ───────────────────────────────────────────────────────────────────

def big_hammer(r, scale=1.0, gold=False):
    kw = dict(spread=2.8, dither=0.14)
    _, hand, s_top, d = grip(r)
    p = np.array([d[1], -d[0]]); p = -p if p[0] < 0 else p
    pommel = np.array(hand) - d * 6.0
    end = np.array(s_top) + d * (11.0 + (scale - 1) * 4)
    back, front = Part(), Part()
    back.part(); back.capsule(tuple(np.array(s_top) - d * 1.0), tuple(end), 1.9, 1.9, 'R', bias=-0.2, **kw)
    back.part(); back.capsule(tuple(end - p * 4.6 * scale), tuple(end + p * 4.6 * scale), 3.4 * scale, 3.4 * scale, 'D', bias=-0.1, **kw)
    for side in (-1, 1):
        a = end + p * side * 4.4 * scale
        b = end + p * side * 8.0 * scale
        back.part(); back.capsule(tuple(a), tuple(b), 4.8 * scale, 4.8 * scale, 'D', bias=0.25, **kw)
        for t in np.linspace(-3.6 * scale, 3.6 * scale, 9):
            q = end + p * side * 12.0 * scale + d * t
            back.px(int(round(q[0])), int(round(q[1])), 'M', 3 if side < 0 else 2)
        ring = end + p * side * 4.3 * scale
        for t in np.linspace(-3 * scale, 3 * scale, 7):
            q = ring + d * t
            back.px(int(round(q[0])), int(round(q[1])), 'Y' if gold else 'O', 3 if int(t) % 2 else 2)
    if gold:
        for side in (-1, 1):  # bordas de ouro nas faces
            for t in np.linspace(-4.2 * scale, 4.2 * scale, 11):
                q = end + p * side * 7.6 * scale + d * t
                back.px(int(round(q[0])), int(round(q[1])), 'Y', 3)
        rune = [(-2.4, 1.4), (-1.2, -1.2), (0, 1.4), (1.2, -1.2), (2.4, 1.4)]
        for (a, b) in zip(rune, rune[1:]):
            for t in np.linspace(0, 1, 4):
                q = end + p * (a[0] + (b[0] - a[0]) * t) + d * (a[1] + (b[1] - a[1]) * t)
                back.px(int(round(q[0])), int(round(q[1])), 'O', 4)
    else:
        core = back.mask_ellipse(end[0], end[1], 2.1, 2.1)
        back.part(); back.ellipsoid(core, end[0] - 0.5, end[1] - 0.5, 2.1, 2.1, 'O', bias=0.9, spread=1.6, dither=0.1)
    back.seams()
    front.part(); front.capsule(tuple(pommel), tuple(s_top), 1.9, 1.9, 'R', bias=0.0, **kw)
    for t in (0.55, 0.68, 0.81):
        q = pommel + (np.array(s_top) - pommel) * t
        front.px(int(round(q[0])), int(round(q[1])), 'D', 1); front.px(int(round(q[0])) + 1, int(round(q[1])), 'D', 2)
    pm = front.mask_ellipse(pommel[0], pommel[1], 2.3, 2.3)
    front.part(); front.ellipsoid(pm, pommel[0] - 0.6, pommel[1] - 0.6, 2.3, 2.3, 'Y' if gold else 'M', bias=0.2, **kw)
    front.seams()
    return back, front


def judge_hammer(r):
    """Martelo do Juiz: cabeça maior, bordas de ouro e runa de brasa."""
    return big_hammer(r, scale=1.22, gold=True)


def apprentice_hammer(r):
    """Martelo de aprendiz: o mesmo gesto, cabeça um pouco menor."""
    return big_hammer(r, scale=0.88, gold=False)


def staff(r):
    """Cajado do Erudito: em pé ao lado do corpo, apoiado no chão, com o orbe aceso no alto."""
    L = Part()
    hx_, hy_ = mirror((r['hand'][0], r['hand'][1]))
    x = hx_ + 0.4
    L.part(); L.capsule((x, 90), (x - 0.3, 12), 1.4, 1.2, 'R', bias=-0.1, **KW)
    for y in range(20, 88, 9):
        L.px(int(x), y, 'Y', 2)
    for side in (-1, 1):  # garras que seguram o orbe
        L.part(); L.capsule((x, 12), (x + side * 3.2, 5.5), 0.9, 0.7, 'Y', bias=0.2, **KW)
    orb = L.mask_ellipse(x, 6.5, 3.2, 3.2)
    L.part(); L.ellipsoid(orb, x - 0.8, 5.7, 3.2, 3.2, 'T', bias=0.8, spread=1.8, dither=0.1)
    L.px(int(x - 1), 5, 'T', 4)
    L.seams()
    return L, None


def blade(r):
    """Lâmina do Foco: espada na mão, ponta para baixo e para fora, fio de luz ciano."""
    L = Part()
    hx_, hy_ = mirror((r['hand'][0], r['hand'][1]))
    grip_top = (hx_ - 0.6, hy_ - 3.5)
    tip = (hx_ + 9.5, 88)
    guard_c = (hx_ + 0.6, hy_ + 3.2)
    L.part(); L.capsule(grip_top, (hx_ + 0.4, hy_ + 2), 1.3, 1.3, 'R', bias=0, **KW)
    pm = L.mask_ellipse(grip_top[0], grip_top[1] - 1, 1.6, 1.6)
    L.part(); L.ellipsoid(pm, grip_top[0] - 0.5, grip_top[1] - 1.5, 1.6, 1.6, 'Y', bias=0.3, **KW)
    d = np.array(tip) - np.array(guard_c); d = d / np.linalg.norm(d)
    p = np.array([d[1], -d[0]])
    guard = L.mask_line([tuple(np.array(guard_c) - p * 4.2), tuple(np.array(guard_c) + p * 4.2)], 2)
    L.part(); L.cylinder(guard, 'Y', bias=0.2, axis='h', **KW)
    base = np.array(guard_c) + d * 1.5
    poly = [tuple(base - p * 1.9), tuple(base + p * 1.9), tuple(np.array(tip) + p * 0.4), tuple(np.array(tip) - p * 0.4)]
    bl = L.mask_poly(poly)
    L.part(); L.cylinder(bl, 'M', bias=0.3, spread=3.0, dither=0.06)
    for t in np.linspace(0.05, 0.95, 30):  # fio de luz
        q = base + (np.array(tip) - base) * t - p * (1.4 * (1 - t))
        L.px(int(round(q[0])), int(round(q[1])), 'T', 4 if t < 0.5 else 3)
    L.seams()
    return L, None


# ── amuletos ────────────────────────────────────────────────────────────────

def amulet(aid, r):
    L = Part()
    cy = 37.5 if not r['female'] else 35.2
    for side in (-1, 1):  # corrente
        for t in np.linspace(0, 1, 7):
            x = int(round(48 + side * (4.8 - 4.2 * t))); y = int(round(28.8 + (cy - 31.5) * t))
            L.px(x, y, 'M', 3 if t * 7 % 2 < 1 else 2)
    if aid == 'amu_ampulheta':
        m = L.mask_poly([(45.6, cy - 1), (50.4, cy - 1), (48.4, cy + 2.2), (50.4, cy + 5.2), (45.6, cy + 5.2), (47.6, cy + 2.2)])
        L.part(); L.flat(m, 'Y', 2)
        L.px(47, int(cy), 'W', 4); L.px(48, int(cy + 4), 'O', 4); L.px(47, int(cy + 4), 'O', 3); L.px(49, int(cy + 4), 'O', 3)
        for x in range(45, 52):
            L.px(x, int(cy - 1), 'Y', 3); L.px(x, int(cy + 5), 'Y', 1)
    elif aid == 'amu_calma':
        m = L.mask_poly([(48, cy - 1.2), (50.4, cy + 2.4), (48, cy + 5), (45.6, cy + 2.4)])
        L.part(); L.ellipsoid(m, 47.2, cy + 1, 2.8, 3.2, 'T', bias=0.4, spread=2.0, dither=0.05)
        L.px(47, int(cy + 1), 'T', 4)
    elif aid == 'amu_equilibrio':
        m = L.mask_ellipse(48, cy + 2, 2.9, 2.9)
        L.part(); L.ellipsoid(m, 47.2, cy + 1.2, 2.9, 2.9, 'Y', bias=0.2, spread=2.4, dither=0.05)
        for k in range(5):
            a = -np.pi / 2 + k * 2 * np.pi / 5
            L.px(int(round(48 + np.cos(a) * 1.7)), int(round(cy + 2 + np.sin(a) * 1.7)), 'O', 3)
    L.seams()
    return L


# ── montagem ────────────────────────────────────────────────────────────────

HAIR_STYLES = ['raspado', 'curto', 'franja', 'cacheado', 'longo', 'coque', 'volumoso', 'sem']
WEAPONS = {'arm_martelo': apprentice_hammer, 'arm_martelo_juiz': judge_hammer, 'arm_cajado': staff, 'arm_lamina': blade}
SHOULDER = {'arm_martelo', 'arm_martelo_juiz'}


def build():
    layers = {}
    def put(name, L, part):
        if L is not None and (L.mat != '').any():
            layers[name] = dict(px=L.encode(), part=part)
    for g, r in RIG.items():
        b, neck = body(r)
        put(f'corpo_{g}', b, 'body'); put(f'pescoco_{g}', neck, 'body')
        put(f'cabeca_{g}', head(r), 'head')
        put(f'rosto_{g}', face(r), 'head'); put(f'rosto_{g}_piscar', face(r, True), 'head')
        arm, _ = right_arm(r, False)
        arm_h, (fore_h, hand_h) = right_arm(r, True)
        put(f'braco_{g}', arm, 'body'); put(f'braco_ombro_{g}', arm_h, 'body')
        put(f'antebraco_ombro_{g}', fore_h, 'body'); put(f'mao_ombro_{g}', hand_h, 'body')
        for s in HAIR_STYLES:
            fr, bk = hair(s, r)
            put(f'cabelo_{s}_{g}', fr, 'head'); put(f'cabelo_{s}_tras_{g}', bk, 'head')
        for k in (1, 2):
            put(f'barba_{k}_{g}', beard(k, r), 'head')
        put(f'cab_faixa_{g}', headband(r), 'head')
        fr, bk = hood(r); put(f'cab_capuz_{g}', fr, 'head')
        put(f'cab_elmo_silencio_{g}', silence_helm(r), 'head')
        put(f'cab_elmo_ferro_{g}', iron_helm(r), 'head')
        put(f'cab_coroa_{g}', ember_crown(r), 'head')
        put(f'cor_gibao_{g}', jerkin(r), 'body')
        put(f'cor_malha_{g}', chainmail(r), 'body')
        put(f'cor_sentinela_{g}', sentinel(r), 'body')
        put(f'cor_placas_{g}', plates(r), 'body')
        for cid in CAPES:
            bk, fr = cape(cid, r)
            put(f'{cid}_tras_{g}', bk, 'body'); put(f'{cid}_{g}', fr, 'body')
        for wid, fn in WEAPONS.items():
            bk, fr = fn(r)
            put(f'{wid}_tras_{g}', bk, 'body'); put(f'{wid}_{g}', fr, 'body')
        for aid in ('amu_ampulheta', 'amu_calma', 'amu_equilibrio'):
            put(f'{aid}_{g}', amulet(aid, r), 'body')
    return layers


if __name__ == '__main__':
    out = build()
    json.dump(out, open(sys.argv[1], 'w'), separators=(',', ':'))
    print(len(out), 'camadas')
