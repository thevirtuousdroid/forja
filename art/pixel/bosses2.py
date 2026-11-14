"""Forja · chefes em pixel, segunda versão: mais peças, juntas, cabos, telas e objetos de cena.

Usa as ferramentas de bosses.py (bolas sombreadas, linhas finas, raios, acabamento de painéis).
"""
import sys, math
import numpy as np
import bosses as B
from bosses import line1, bolt, eye_slit, detail_pass, KW
from character2 import Part
from character5 import _ball
from engine import raw, SCALE as S


def plate(L, pts, mat, bias=0.0, axis='v', tilt=0.0):
    m = L.mask_poly(pts)
    L.part(); L.cylinder(m, mat, bias=bias, axis=axis, tilt=tilt, **KW)
    return m


def orb(L, x, y, rx, ry, mat, bias=0.0, glow=False):
    m = L.mask_ellipse(x, y, rx, ry)
    if glow:
        L.part(); L.ellipsoid(m, x - rx * 0.3, y - ry * 0.3, rx, ry, mat, bias=0.9, spread=1.6, dither=0.05)
    else:
        L.part(); L.ellipsoid(m, x - rx * 0.35, y - ry * 0.35, rx * 1.1, ry * 1.1, mat, bias=bias, **KW)
    return m


def limb(L, a, b, r0, r1, mat, bias=0.0):
    L.part(); L.capsule(a, b, r0, r1, mat, bias=bias, **KW)


def joint(L, x, y, r, mat='M'):
    orb(L, x, y, r, r, mat, bias=0.2)
    L.px1(x - r * 0.35, y - r * 0.35, mat, 4)


def cable(L, pts, w, mat='J', light=None, f=0, every=5):
    m = L.mask_line(pts, w)
    L.part(); L.cylinder(m, mat, bias=-0.1, **KW)
    if light:
        for i, (x, y) in enumerate(pts[1:-1]):
            if (i + f) % every == 0:
                L.px1(x, y, light, 4)
    return m


def bez(p0, p1, p2, n=20):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]) for t in np.linspace(0, 1, n)]


def glyph_text(L, x, y, n, mat, lvl, rng, h=1.0):
    """Linhas de 'texto' em pixel fino: traços curtos com espaços."""
    cx = x
    for k in range(n):
        w = rng.integers(1, 4) * 0.5
        line1(L, (cx, y), (cx + w, y), mat, lvl)
        if rng.random() < 0.4:
            L.px1(cx, y - 0.5 * h, mat, lvl)
        cx += w + 0.5


def claw_hand(L, x, y, s, f=0, mat='D'):
    orb(L, x, y, 2.4, 2.2, mat, bias=0.1)
    for j in (-1, 0, 1):
        a = (x + j * 1.5, y + 1.4)
        b = (x + j * 2.0 + s * 0.8, y + 4.6)
        c = (x + j * 1.6 + s * 1.6, y + 7.2 - abs(j) * 0.6)
        limb(L, a, b, 0.75, 0.6, 'M', 0.2)
        limb(L, b, c, 0.6, 0.35, 'M', 0.1)


# ── 1. A Tempestade Interna ─────────────────────────────────────────────────

def tempestade(f):
    L = Part()
    rng = np.random.default_rng(300 + f)
    bob = [0, -0.6, -1.1, -0.6][f]
    # nuvem de tempestade: massa escura com bordas claras e clarões internos
    crng = np.random.default_rng(5)
    blobs = [(48 + crng.uniform(-22, 22), 26 + crng.uniform(-9, 7), crng.uniform(4, 7.5)) for _ in range(26)]
    for (x, y, r) in sorted(blobs, key=lambda b: b[1]):
        _ball(L, x + math.sin(f * 1.57 + x) * 0.5, y + bob * 0.5, r, r * 0.8, bias=-1.1, mat='B')
    M, V = raw(L.mat), raw(L.lvl)
    flash = [(36, 22), (60, 20), (44, 32), (58, 31)][f]
    yy, xx = np.mgrid[0:M.shape[0], 0:M.shape[1]] / S
    fl = (M == 'B') & (((xx - flash[0]) ** 2 + (yy - flash[1]) ** 2) < 40)
    V[fl] = np.minimum(4, V[fl] + 2)
    # tornado de vento no lugar das pernas: espirais finas e destroços orbitando
    for k in range(5):
        for t in np.linspace(0, 1, 90):
            y = 60 + t * 30 + bob
            w = (12 - t * 10) * (1 + 0.08 * k)
            a = t * 14 + k * 1.25 + f * 0.9
            x = 48 + math.cos(a) * w + math.sin(t * 6 + f) * 1.2
            front = math.sin(a) > 0
            L.px1(x, y + math.sin(a) * 1.2, 'B', (4 if front else 2) if (int(t * 90) + k) % 6 else 3)
    for k in range(7):  # destroços
        a = k / 7 * 2 * math.pi + f * 0.45
        x = 48 + math.cos(a) * (14 - k * 0.8); y = 70 + k * 2.6 + bob + math.sin(a) * 2
        sh = [(x - 1.3, y - 0.8), (x + 1.1, y - 1.2), (x + 1.4, y + 0.9), (x - 0.9, y + 1.1)]
        plate(L, sh, 'D' if k % 2 else 'M', bias=0.2)
    # braços: ombro em esfera, bíceps com tubo de luz, cotovelo, antebraço blindado, garra
    for s in (-1, 1):
        sh = (48 + s * 14, 46 + bob)
        el = (48 + s * 21, 55 + bob)
        hd = (48 + s * 25, 64 + bob)
        limb(L, sh, el, 2.4, 2.0, 'J')
        for t in np.linspace(0.15, 0.85, 8):
            L.px1(sh[0] + (el[0] - sh[0]) * t + s * 0.5, sh[1] + (el[1] - sh[1]) * t, 'B', 4 if (int(t * 8) + f) % 3 else 2)
        joint(L, *el, 2.2)
        fa = [(el[0] - 2.4, el[1] + 1), (el[0] + 2.4, el[1] + 1), (hd[0] + 2.2 * s * 0.5 + 2, hd[1] - 1.5), (hd[0] - 2, hd[1] - 1.5)]
        plate(L, fa, 'D', bias=0.15)
        line1(L, (el[0], el[1] + 2), (hd[0], hd[1] - 2), 'D', 0)
        claw_hand(L, hd[0], hd[1], s, f)
        if (f + (s > 0)) % 2 == 0:  # faísca entre as garras
            bolt(L, hd[0] - 1.5, hd[1] + 6, hd[0] + 1.5, hd[1] + 6.5, rng, segs=3, jit=0.8)
        orb(L, sh[0], sh[1], 4.6, 4.2, 'M', bias=0.15)
        line1(L, (sh[0] - 3.6, sh[1] + 0.5), (sh[0] + 3.6, sh[1] + 0.5), 'M', 0)
        L.px1(sh[0], sh[1] - 1.5, 'B', 4); L.px1(sh[0] + 0.5, sh[1] - 1.5, 'B', 3)
    # tronco: peitoral com gola, abdome em segmentos, grade de ventilação
    for k in range(3):
        y = 58 + k * 2.2 + bob
        plate(L, [(41 + k * 1.4, y), (55 - k * 1.4, y), (54 - k * 1.4, y + 2), (42 + k * 1.4, y + 2)], 'D', bias=0.1 - k * 0.15, axis='h')
    chest = L.mask_poly([(35, 42 + bob), (61, 42 + bob), (60, 51 + bob), (55, 58 + bob), (41, 58 + bob), (36, 51 + bob)])
    L.part(); L.cylinder(chest, 'D', bias=0.05, tilt=0.4, spread=3.0, dither=0.08)
    line1(L, (48, 43 + bob), (48, 57 + bob), 'D', 0)
    for s in (-1, 1):  # grades laterais com luz azul
        for k in range(4):
            y = 47 + k * 2 + bob
            line1(L, (48 + s * 6, y), (48 + s * 10.5 - (k * 0.6) * s, y), 'B', 3 if (k + f) % 2 else 2)
            line1(L, (48 + s * 6, y + 0.5), (48 + s * 10.5 - (k * 0.6) * s, y + 0.5), 'D', 0)
    ring = orb(L, 48, 49 + bob, 4.0, 4.0, 'M', bias=0.1)
    orb(L, 48, 49 + bob, 2.6, 2.6, 'O', glow=True)
    for k in range(8):
        a = k / 8 * 2 * math.pi + f * 0.4
        L.px1(48 + math.cos(a) * 3.4, 49 + bob + math.sin(a) * 3.4, 'O', 4 if k % 2 else 2)
    collar = plate(L, [(39, 39.5 + bob), (57, 39.5 + bob), (58.5, 42.5 + bob), (37.5, 42.5 + bob)], 'M', bias=0.25, axis='h')
    for x in np.arange(40, 57, 2.5):
        L.px1(x, 41 + bob, 'D', 0)
    # pescoço: feixe de cabos
    for k, dx in enumerate((-2.2, -0.8, 0.8, 2.2)):
        cable(L, [(48 + dx, 40 + bob), (48 + dx * 1.2, 37.5 + bob)], 1.3, 'J' if k % 2 else 'D')
    # cúpula de vidro com o cérebro e coroa de eletrodos
    base = plate(L, [(38.5, 34 + bob), (57.5, 34 + bob), (56, 38 + bob), (40, 38 + bob)], 'M', bias=0.2, axis='h')
    for x in range(40, 57, 3):
        L.px1(x + 0.5, 36 + bob, 'O', 4 if (x + f) % 2 else 3)
    dome = L.mask_ellipse(48, 27.5 + bob, 8.6, 7.6)
    raw(dome)[int((34 + bob) * S):, :] = False
    L.part(); L.ellipsoid(dome, 45.6, 25 + bob, 9, 8.2, 'T', bias=-1.0, spread=2.2, dither=0.06)
    brain = L.mask_ellipse(48, 28.5 + bob, 6.2, 4.9)
    L.part(); L.ellipsoid(brain, 46.4, 27 + bob, 6.4, 5.2, 'P', bias=0.15, spread=2.4, dither=0.08)
    for k in range(7):  # sulcos curvos do cérebro
        cx = 43 + k * 1.6; cy = 28.5 + bob
        for t in np.linspace(-1, 1, 7):
            L.px1(cx + math.sin(t * 2 + k) * 0.7, cy + t * 3.2, 'P', 1)
    line1(L, (48, 24 + bob), (48, 33 + bob), 'P', 0)
    for (x, y) in ((42.5, 23.5), (43, 23), (43.5, 22.6), (44.5, 22.2), (42.3, 24.5)):
        L.px1(x, y + bob, 'W', 4)
    for k in range(6):  # eletrodos
        a = math.pi * (1.1 + k * 0.16)
        x0, y0 = 48 + math.cos(a) * 8.4, 27.5 + bob + math.sin(a) * 7.4
        x1, y1 = 48 + math.cos(a) * 11.5, 27.5 + bob + math.sin(a) * 10.5
        limb(L, (x0, y0), (x1, y1), 0.45, 0.35, 'M', 0.2)
        L.px1(x1, y1, 'B', 4); L.px1(x1 + 0.5, y1, 'W', 4)
    L.seams()
    # raios entre eletrodos e da nuvem até o chão
    for _ in range(2 + f % 2):
        a = math.pi * rng.uniform(1.1, 1.9)
        bolt(L, 48 + math.cos(a) * 11.5, 27.5 + bob + math.sin(a) * 10.5, 48 + math.cos(a) * 26, 22 + math.sin(a) * 14, rng, segs=5, jit=2.2)
    s = 1 if f % 2 else -1
    bolt(L, 48 + s * 20, 30, 48 + s * rng.uniform(22, 32), 92, rng, segs=8, jit=2.6)
    return L


# ── 2. O Adiador ────────────────────────────────────────────────────────────

def adiador(f):
    L = Part()
    rng = np.random.default_rng(11)
    # fumaça lenta dos escapamentos (atrás)
    for s in (-1, 1):
        x0 = 48 + s * 11
        limb(L, (x0, 40), (x0 + s * 2, 26), 1.6, 1.4, 'D', 0.0)
        orb(L, x0 + s * 2, 26, 2.2, 1.2, 'M', 0.1)
        for k in range(3):
            t = (f + k * 1.33) % 4
            _ball(L, x0 + s * (2 + t * 0.8), 23 - t * 3 - k * 0.4, 1.4 + t * 0.5, 1.1 + t * 0.4, bias=-0.6 - t * 0.15, mat='M')
    # pilha de tarefas: caixas com fita, papéis, caneca, placa "TO DO"
    for k in range(9):
        x = 26 + k * 5.6 + rng.uniform(-1, 1); y = 87 + rng.uniform(-1, 2.5)
        w, h = rng.uniform(5, 7), rng.uniform(4, 5.5)
        bx = plate(L, [(x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2), (x - w / 2, y + h / 2)], 'R', bias=0.1)
        line1(L, (x, y - h / 2), (x, y + h / 2), 'Y', 2)
        line1(L, (x - w / 2, y - h / 2 + 0.5), (x + w / 2, y - h / 2 + 0.5), 'R', 4)
    for k in range(12):
        x = 22 + rng.uniform(0, 52); y = 82 + rng.uniform(0, 6)
        a = rng.uniform(-0.5, 0.5); c_, s_ = math.cos(a), math.sin(a)
        pts = [(x + c_ * dx - s_ * dy, y + s_ * dx + c_ * dy) for dx, dy in ((-2.5, -1.8), (2.5, -1.8), (2.5, 1.8), (-2.5, 1.8))]
        plate(L, pts, 'W', bias=0.3)
        for j in range(3):
            line1(L, (x - 1.6, y - 0.9 + j * 0.9), (x + 1.2 - j * 0.4, y - 0.9 + j * 0.9), 'W', 0)
    mug = plate(L, [(70, 80), (75, 80), (74.6, 86), (70.4, 86)], 'W', bias=0.1)
    L.part(); L.capsule((75.4, 82), (75.4, 84.4), 1.0, 1.0, 'W', bias=0.0, **KW)
    for k in range(2):
        L.px1(71.5 + k * 1.5, 78.5 - (f % 2) * 0.5 - k * 0.5, 'W', 2)
    # pernas dobradas com joelheiras
    for s in (-1, 1):
        limb(L, (48 + s * 9, 70), (48 + s * 17, 78), 5.0, 4.4, 'D', -0.1)
        limb(L, (48 + s * 17, 78), (48 + s * 14, 87), 4.0, 3.6, 'D', -0.2)
        joint(L, 48 + s * 17, 78, 3.2)
        plate(L, [(48 + s * 14 - 4.5, 86), (48 + s * 14 + 4.5, 86), (48 + s * 14 + 5, 91), (48 + s * 14 - 5, 91)], 'M', 0.0, axis='h')
    # cabo de extensão da barriga até a pilha
    cable(L, bez((40, 68), (30, 80), (24, 84)), 1.4, 'J')
    plate(L, [(22, 83), (25.5, 83), (25.5, 86), (22, 86)], 'M', 0.2)
    # corpo corcunda
    back = L.mask_ellipse(48, 55, 20.5, 19)
    raw(back)[int(74 * S):, :] = False
    L.part(); L.ellipsoid(back, 41, 45, 22, 20, 'D', bias=0.0, spread=3.0, dither=0.1)
    for (x, y, r_) in ((32, 50, 3.2), (62, 61, 2.6), (37, 67, 2.2), (60, 46, 1.8)):  # ferrugem com escorrido
        rm = L.mask_ellipse(x, y, r_, r_ * 0.8) & back
        L.flat(rm, 'R', 2)
        line1(L, (x, y + r_ * 0.6), (x + 0.5, y + r_ * 0.6 + 3), 'R', 1)
    # post-its colados
    for k, (x, y, a) in enumerate(((35, 44, -0.2), (60, 53, 0.25), (33, 60, 0.1))):
        c_, s_ = math.cos(a), math.sin(a)
        pts = [(x + c_ * dx - s_ * dy, y + s_ * dx + c_ * dy) for dx, dy in ((-2.4, -2.4), (2.4, -2.4), (2.4, 2.4), (-2.4, 2.4))]
        plate(L, pts, 'Y', 0.4)
        for j in range(2):
            line1(L, (x - 1.4, y - 0.6 + j * 1.2), (x + 1.2, y - 0.6 + j * 1.2), 'Y', 1)
    # calendário com dias riscados
    cal = plate(L, [(55, 64), (63, 63), (63.5, 71), (55.5, 72)], 'W', 0.2)
    line1(L, (55, 64.5), (63, 63.5), 'F', 3); line1(L, (55, 65), (63, 64), 'F', 3)
    for i in range(3):
        for j in range(3):
            x = 56.6 + i * 2.2; y = 66.6 + j * 1.7
            L.px1(x, y, 'F', 3); L.px1(x + 0.5, y + 0.5, 'F', 3)
    # relógio no ombro com engrenagens
    for k, (x, y, r_) in enumerate(((58, 37, 2.6), (68, 45, 2.0))):
        orb(L, x, y, r_, r_, 'Y', 0.1)
        for j in range(8):
            a = j / 8 * 2 * math.pi + f * 0.1 * (1 if k else -1)
            L.px1(x + math.cos(a) * (r_ + 0.4), y + math.sin(a) * (r_ + 0.4), 'Y', 3)
    orb(L, 64, 39, 5.2, 5.2, 'Y', 0.15)
    L.part(); L.flat(L.mask_ellipse(64, 39, 3.8, 3.8), 'W', 3)
    for j in range(12):
        a = j / 12 * 2 * math.pi
        L.px1(64 + math.cos(a) * 3.2, 39 + math.sin(a) * 3.2, 'K', 1 if j % 3 else 0)
    line1(L, (64, 39), (64, 36.2), 'K', 0)
    line1(L, (64, 39), (66.2 - f * 0.05, 40.2), 'F', 3)
    # ampulheta ornamentada
    for yy in (51, 71):
        plate(L, [(39, yy - 1.6), (57, yy - 1.6), (56, yy + 1.6), (40, yy + 1.6)], 'Y', 0.2, axis='h')
        for x in np.arange(41, 56, 2.5):
            L.px1(x, yy, 'Y', 4)
    for s in (-1, 1):
        for t in np.linspace(0, 1, 10):
            y = 53 + t * 16
            L.px1(48 + s * 7.2 + math.sin(t * 12) * 0.5, y, 'Y', 3 if int(t * 10) % 2 else 1)
            L.px1(48 + s * 7.7 + math.sin(t * 12) * 0.5, y, 'Y', 2)
    glass = L.mask_poly([(42.4, 53), (53.6, 53), (49.4, 61), (53.6, 69), (42.4, 69), (46.6, 61)])
    L.part(); L.flat(glass, 'T', 1)
    sand = L.mask_poly([(43.4, 54), (52.6, 54), (49.6, 59.2), (46.4, 59.2)])
    L.part(); L.cylinder(sand, 'O', bias=0.3, axis='h', **KW)
    for k in range(10):
        L.px1(44 + rng.uniform(0, 8), 54.5 + rng.uniform(0, 3.5), 'O', 4 if k % 3 else 2)
    pile = L.mask_poly([(44.5, 69), (51.5, 69), (48, 67.6)])
    L.part(); L.flat(pile, 'O', 2)
    L.px1(48, 61 - (0.5 if f % 2 else 0), 'O', 4)
    for (x, y) in ((43.5, 54.5), (44, 64.5), (44.5, 65)):
        L.px1(x, y, 'T', 4)
    for (x, y) in ((45, 63.5), (51.5, 65.5), (46.5, 67)):
        line1(L, (x, y), (x + 1.5, y + 1.6), 'T', 4)
    # braços: um apoiado na pilha, o outro segurando o celular perto do rosto
    for s in (-1, 1):
        shp = (48 + s * 16, 43)
        orb(L, shp[0], shp[1], 6.2, 5.4, 'M', 0.15)
        line1(L, (shp[0] - 4.5, shp[1] + 1.6), (shp[0] + 4.5, shp[1] + 1.6), 'M', 0)
    limb(L, (32, 46), (25, 64), 4.0, 3.4, 'D', 0.1)
    joint(L, 25, 64, 2.8)
    limb(L, (25, 64), (25, 80), 3.2, 2.8, 'D', 0.0)
    orb(L, 25, 82.5, 4.4, 3.0, 'M', 0.1)
    for j in range(3):
        limb(L, (22.5 + j * 2.4, 84), (22 + j * 2.6, 86.6), 0.8, 0.7, 'M', 0.1)
    limb(L, (64, 46), (68, 56), 4.0, 3.4, 'D', 0.1)
    joint(L, 68, 56, 2.8)
    limb(L, (68, 56), (60, 49), 3.0, 2.6, 'D', 0.0)
    ph = plate(L, [(55.5, 44.5), (60.5, 44), (61, 52), (56, 52.5)], 'J', 0.1)
    scr = L.mask_poly([(56.3, 45.3), (60, 45), (60.3, 51.2), (56.6, 51.5)])
    L.part(); L.flat(scr, 'P', 2)
    for j in range(4):  # rolando a tela
        y = 46 + ((j * 1.5 + f * 0.75) % 5.5)
        line1(L, (56.8, y), (59.6 - (j % 2), y), 'P', 4)
    orb(L, 60, 50, 2.2, 2.0, 'M', 0.1)
    # cabeça caída, olhando o celular, com antena torta
    hy = 37 + [0, 0.4, 0.8, 0.4][f]
    limb(L, (50, hy - 5), (53, hy - 10), 0.4, 0.35, 'M', 0.2)
    limb(L, (53, hy - 10), (57, hy - 9), 0.35, 0.3, 'M', 0.2)
    L.px1(57.5, hy - 9, 'O', 4 if f % 2 else 2)
    orb(L, 48, hy, 7.6, 6.2, 'D', 0.2)
    line1(L, (41, hy - 2.5), (55, hy - 2.5), 'D', 0)
    for s in (-1, 1):  # bochechas com grade
        for k in range(3):
            line1(L, (48 + s * 5.2, hy + 1 + k), (48 + s * 6.8, hy + 1 + k), 'D', 0)
    vis = plate(L, [(41.6, hy - 1), (54.4, hy - 1), (53.4, hy + 2.4), (42.6, hy + 2.4)], 'J', -0.5, axis='h')
    for s in (-1, 1):
        for k in range(-3, 4):
            L.px1(48 + s * 2.8 + k * 0.5 + 0.8, hy + 1.4, 'O', 4 if abs(k) < 2 else 3)
        line1(L, (48 + s * 2.8 - 1.5 + 0.8, hy + 0.7), (48 + s * 2.8 + 1.5 + 0.8, hy + 0.7), 'D', 1)  # pálpebra pesada
    L.seams()
    for k in range(3):  # Z z z
        y = 24 - ((f + k * 1.4) % 4) * 2.4 - k * 2
        x = 30 - k * 4
        sz = 1.6 - k * 0.3
        line1(L, (x, y), (x + sz * 2, y), 'T', 4); line1(L, (x + sz * 2, y), (x, y + sz * 2), 'T', 4); line1(L, (x, y + sz * 2), (x + sz * 2, y + sz * 2), 'T', 4)
    return L


# ── 3. A Hidra das Notificações ─────────────────────────────────────────────

def hidra(f):
    L = B.hidra(f)
    rng = np.random.default_rng(f)
    # base: rack de servidores e cabos entrando no chão
    for k in range(-2, 3):
        x = 48 + k * 8
        for t in np.linspace(0, 1, 8):
            L.px1(x + math.sin(t * 4 + k) * 1.5, 92 + t * 3, 'J', 2)
    for s in (-1, 1):
        rk = plate(L, [(48 + s * 24, 78), (48 + s * 31, 78), (48 + s * 31, 92), (48 + s * 24, 92)], 'D', 0.0)
        for j in range(5):
            y = 80 + j * 2.4
            line1(L, (48 + s * 24.6, y), (48 + s * 30.4, y), 'D', 0)
            L.px1(48 + s * 25.5, y + 1, 'T' if (j + f) % 3 else 'P', 4)
            L.px1(48 + s * 26.5, y + 1, 'O' if (j + f) % 2 else 'D', 3)
        cable(L, bez((48 + s * 24, 84), (48 + s * 22, 88), (48 + s * 18, 88)), 1.2, 'J', 'T', f)
    # balões de notificação com números
    spots = [(31, 21), (60, 10), (83, 19), (25, 50), (90, 47)]
    for k, (x, y) in enumerate(spots):
        if (k + f) % 4 == 3:
            continue
        orb(L, x, y, 2.6, 2.6, 'F', 0.6)
        n = (k * 7 + f) % 9 + 1
        for (dx, dy) in {1: ((0, -1), (0, 0), (0, 1)), 7: ((-0.5, -1), (0, -1), (0.5, -1), (0.5, -0.5), (0, 0.5), (0, 1))}.get(n % 2 and 1 or 7):
            L.px1(x + dx, y + dy, 'W', 4)
    for k in range(4):  # ícones flutuando (coração e !)
        x = 20 + k * 19 + math.sin(f + k) * 1.5; y = 6 + (f * 1.5 + k * 3) % 8
        if k % 2:
            for (dx, dy) in ((-1, 0), (1, 0), (-1.5, -0.5), (1.5, -0.5), (0, 1), (-0.5, 0.5), (0.5, 0.5), (0, 0)):
                L.px1(x + dx, y + dy, 'P', 4)
        else:
            line1(L, (x, y - 1.5), (x, y + 0.5), 'O', 4); L.px1(x, y + 1.5, 'O', 4)
    return L


# ── 4. A Névoa do Esquecimento ──────────────────────────────────────────────

def nevoa(f):
    L = Part()
    rng = np.random.default_rng(14)
    bob = [0, -0.6, -1, -0.6][f]
    # véus de névoa atrás (mais escuros), corpo, e fiapos
    for k in range(9):
        a = k / 9 * 2 * math.pi + f * 0.1
        _ball(L, 48 + math.cos(a) * 17, 48 + bob + math.sin(a) * 21, 6.5, 5.5, bias=-1.3, mat='N')
    body = L.mask_ellipse(48, 45 + bob, 18, 22) | L.mask_ellipse(48, 61 + bob, 14, 10)
    L.part(); L.ellipsoid(body, 43, 38 + bob, 20, 26, 'N', bias=0.05, spread=2.6, dither=0.1)
    M, V = raw(L.mat), raw(L.lvl)
    ys, xs = np.where(raw(body))
    for Y, X in zip(ys, xs):
        x, y = X / S, Y / S
        w = math.sin(x * 0.5 + math.sin(y * 0.33 + f * 0.8) * 2.4) + math.sin(y * 0.4 - x * 0.22 + f * 0.6)
        if w > 1.1:
            V[Y, X] = min(4, V[Y, X] + 1)
        elif w < -1.15:
            V[Y, X] = max(0, V[Y, X] - 1)
    # memórias se apagando dentro da névoa: letras e uma foto
    for j in range(6):
        y = 50 + j * 2.2 + bob
        if (j + f) % 3 != 0:
            glyph_text(L, 38 + (j % 2) * 2, y, 9 - j, 'N', 4 if j < 2 else 3, rng)
    for (x, y, a) in ((36, 34, -0.15), (58, 60, 0.2)):
        c_, s_ = math.cos(a), math.sin(a)
        pts = [(x + c_ * dx - s_ * dy, y + bob + s_ * dx + c_ * dy) for dx, dy in ((-3, -3.5), (3, -3.5), (3, 3.5), (-3, 3.5))]
        plate(L, pts, 'W', 0.1)
        inner = [(x + c_ * dx - s_ * dy, y + bob + s_ * dx + c_ * dy) for dx, dy in ((-2.2, -2.7), (2.2, -2.7), (2.2, 1.6), (-2.2, 1.6))]
        L.part(); L.flat(L.mask_poly(inner), 'N', 2)
        L.px1(x - 0.5, y + bob - 1, 'N', 4); L.px1(x + 0.5, y + bob - 0.5, 'N', 4)
    for Y, X in zip(*np.where(M != '')):  # bordas se desfazendo
        d = math.hypot(X / S - 48, (Y / S - 47) * 0.78) / 20
        if d > 0.8 and ((X * 7 + Y * 3 + f * 5) % 11) < (d - 0.8) * 70:
            M[Y, X] = ''
    # rosto: olhos fundos com brilho e boca sorrindo
    for s in (-1, 1):
        e = L.mask_ellipse(48 + s * 6, 40 + bob, 2.8, 3.6)
        L.part(); L.flat(e, 'N', 0)
        inner = L.mask_ellipse(48 + s * 6, 41 + bob, 1.6, 2.0)
        L.flat(inner, 'J', 0)
        L.px1(48 + s * 6 - 0.5, 39.5 + bob, 'W', 4 if f != 2 else 2)
        L.px1(48 + s * 6 + 0.5, 41.5 + bob, 'N', 3)
    for k in range(-12, 13):
        x = 48 + k * 0.5; y = 49 + bob + (144 - k * k) / 80
        L.px1(x, y, 'N', 0); L.px1(x, y + 0.5, 'J', 1)
    # livro aberto embaixo, páginas virando névoa
    bk = [(36, 76 + bob), (48, 78 + bob), (60, 76 + bob), (60, 81 + bob), (48, 83 + bob), (36, 81 + bob)]
    plate(L, bk, 'R', 0.0)
    for s in (-1, 1):
        pg = [(48, 77 + bob), (48 + s * 11, 74.6 + bob), (48 + s * 11, 79.4 + bob), (48, 81.6 + bob)]
        plate(L, pg, 'W', 0.2)
        for j in range(4):
            y = 76.4 + j * 1.1 + bob
            line1(L, (48 + s * 2, y + 0.2), (48 + s * (8 - j % 2), y - 0.6), 'N', 2)
    for k in range(14):  # letras subindo do livro e virando pó
        t = ((k * 0.37 + f * 0.25) % 1)
        x = 40 + (k * 5.3) % 16 + math.sin(t * 6 + k) * 1.5; y = 74 - t * 18 + bob
        L.px1(x, y, 'N' if t > 0.5 else 'W', 4 if t < 0.5 else 3)
        if t < 0.4:
            L.px1(x + 0.5, y, 'W', 3)
    # páginas soltas ao redor
    for k, (x, y, ang) in enumerate(((20, 28, -0.3), (76, 34, 0.25), (22, 62, 0.4), (74, 64, -0.2))):
        y += math.sin(f * math.pi / 2 + k) * 1.2
        c_, s_ = math.cos(ang), math.sin(ang)
        corners = [(x + c_ * dx - s_ * dy, y + s_ * dx + c_ * dy) for dx, dy in ((-3, -4), (3, -4), (3, 4), (-3, 4))]
        pg = L.mask_poly(corners)
        L.part(); L.cylinder(pg, 'W', bias=0.2, **KW)
        for j in range(4):
            yy_ = -2.4 + j * 1.5; x0_, x1_ = -2, 1.6 - (j % 2)
            line1(L, (x + c_ * x0_ - s_ * yy_, y + s_ * x0_ + c_ * yy_), (x + c_ * x1_ - s_ * yy_, y + s_ * x1_ + c_ * yy_), 'N', 1)
        for Y, X in zip(*np.where(raw(pg))):
            if (X + Y + f) % 3 == 0 and (Y / S > y + 1.5):
                M[Y, X] = ''
        for j in range(6):
            L.px1(x + 3 + j * 0.9 + f * 0.3, y + 3.5 + math.sin(j + f) * 0.9, 'W' if j < 2 else 'N', 2 + (j < 2))
    # fiapos que descem
    for k in range(6):
        x0 = 36 + k * 4.8
        for t in np.linspace(0, 1, 20):
            x = x0 + math.sin(t * 5 + f + k) * 1.6; y = 84 + bob + t * 8
            if ((int(t * 20) + f + k) % 6) != 0:
                L.px1(x, y, 'N', 3 if t < 0.5 else 2)
    L.seams()
    return L


# ── 5. A Sentinela de Pedra ─────────────────────────────────────────────────

def stone(L, pts, bias=0.1):
    m = L.mask_poly(pts)
    L.part(); L.cylinder(m, 'D', bias=bias, tilt=0.4, spread=3.0, dither=0.1)
    return m


def sentinela(f):
    L = Part()
    glow = [3, 4, 4, 3][f]
    bob = [0, -0.4, -0.6, -0.4][f]
    # pedrinhas levitando
    for k in range(6):
        x = 14 + k * 13 + (k % 2) * 3; y = 18 + (k * 11) % 20 + math.sin(f * 1.57 + k) * 1.2
        stone(L, [(x - 1.6, y - 1), (x + 1.2, y - 1.6), (x + 1.8, y + 1), (x - 1, y + 1.6)], bias=-0.3)
        L.px1(x - 0.5, y - 1, 'T', 2)
    # pernas em blocos com joelho
    for s in (-1, 1):
        stone(L, [(48 + s * 4, 65), (48 + s * 13, 65), (48 + s * 13.5, 74), (48 + s * 4.5, 74)])
        stone(L, [(48 + s * 3.5, 75), (48 + s * 14, 75), (48 + s * 14.5, 85), (48 + s * 3, 85)])
        orb(L, 48 + s * 9, 74.5, 3.0, 2.2, 'D', 0.1)
        stone(L, [(48 + s * 1.5, 85), (48 + s * 16, 85), (48 + s * 17.5, 91.5), (48 + s * 0.5, 91.5)], bias=-0.3)
        for j in range(3):
            line1(L, (48 + s * (4 + j * 4), 86), (48 + s * (4.5 + j * 4), 91), 'M', 0)
    # tronco em blocos separados
    blocks = [[(31, 36), (47.5, 36), (47.5, 46), (28, 46)], [(48.5, 36), (65, 36), (68, 46), (48.5, 46)],
              [(29, 47), (47.5, 47), (47.5, 56), (34, 56)], [(48.5, 47), (67, 47), (62, 56), (48.5, 56)],
              [(35, 57), (61, 57), (59, 65), (37, 65)]]
    for b_ in blocks:
        stone(L, b_)
    Mt, Vt = raw(L.mat), raw(L.lvl)
    for Y, X in zip(*np.where(Mt == 'D')):  # textura de pedra
        n = (X * 13 + Y * 7) % 19
        if n == 0 and Vt[Y, X] > 0: Vt[Y, X] -= 1
        elif n == 5 and Vt[Y, X] < 4: Vt[Y, X] += 1
    # núcleo: runa central e circuitos
    orb(L, 48, 46.5, 3.4, 3.4, 'D', 0.0)
    orb(L, 48, 46.5, 2.0, 2.0, 'T', glow=True)
    for pts in (((40, 38), (43, 42), (41, 45)), ((56, 49), (53, 52), (55, 55)), ((44, 58), (47, 61), (45, 64)), ((60, 39), (57, 43))):
        for a, b in zip(pts, pts[1:]):
            line1(L, a, b, 'T', glow)
    for x0 in (36, 58):  # musgo e trepadeira
        for t in np.linspace(0, 1, 14):
            L.px1(x0 + math.sin(t * 7) * 1.2, 36 + t * 12, 'G', 3 if int(t * 14) % 3 else 4)
        for j in range(5):
            L.px1(x0 - 1 + j * 0.5, 36, 'G', 3)
    # braço esquerdo: ombreira, braço em blocos, punho
    stone(L, [(17, 31), (31, 30), (33, 41), (19, 43)], bias=-0.4)
    for k in range(3):
        L.px1(21 + k * 3.5, 35, 'T', glow)
    stone(L, [(18, 44), (28, 43), (27, 54), (17, 55)])
    orb(L, 22.5, 55, 3, 2, 'D', 0.1)
    fist = L.mask_ellipse(21, 61, 6.4, 5.6)
    L.part(); L.ellipsoid(fist, 19, 59, 6.4, 5.6, 'D', bias=0.1, **KW)
    for k in range(4):
        line1(L, (16 + k * 2.8, 58.5), (16.5 + k * 2.8, 64), 'M', 0)
        L.px1(16.6 + k * 2.8, 58.5, 'M', 4)
    # ombro direito
    stone(L, [(63, 30), (77, 31), (76, 40), (64, 41)], bias=-0.4)
    # cabeça com testa saliente e olho único
    stone(L, [(40, 22 + bob), (56, 22 + bob), (58, 35), (38, 35)], bias=-0.3)
    stone(L, [(38.5, 24.5 + bob), (57.5, 24.5 + bob), (57, 28 + bob), (39, 28 + bob)], bias=0.0)
    vis = L.mask_poly([(41, 29 + bob), (55, 29 + bob), (54.5, 32 + bob), (41.5, 32 + bob)])
    L.part(); L.flat(vis, 'J', 0)
    eye_slit(L, 48 + [-2, 0, 2, 0][f], 30.4 + bob, 4, 'T')
    # escudo-porta: batente, porta com almofadas, maçaneta e fechadura acesa
    door = L.mask_poly([(60, 33), (82, 31), (84, 86), (62, 89), (59, 82)])
    L.part(); L.cylinder(door, 'J', bias=0.2, tilt=-0.3, spread=3.0, dither=0.1)
    inner = L.mask_poly([(63, 36), (79.5, 34.5), (81, 83), (64.5, 85.5), (62.5, 80)])
    L.part(); L.cylinder(inner, 'D', bias=0.0, tilt=-0.3, spread=3.0, dither=0.1)
    for (y0, y1) in ((38, 56), (60, 81)):
        pnl = L.mask_poly([(65.5, y0 + 0.5), (78, y0 - 0.6), (78.6, y1 - 0.6), (66.2, y1 + 0.5)])
        L.part(); L.cylinder(pnl, 'D', bias=0.3, tilt=-0.3, **KW)
        line1(L, (65.5, y0 + 0.5), (78, y0 - 0.6), 'D', 4)
    for (a, b) in (((72, 40), (72, 54)), ((72, 46), (68, 50)), ((72, 46), (76, 50)), ((72, 62), (72, 79)), ((72, 70), (68, 74)), ((72, 70), (76, 74))):
        line1(L, a, b, 'T', glow if a[1] < 60 else glow - 1)
    orb(L, 77.6, 58.6, 1.6, 1.6, 'Y', 0.2)
    keyhole = L.mask_ellipse(77.6, 62, 0.9, 0.9) | L.mask_poly([(77.2, 62), (78, 62), (78.3, 64.2), (76.9, 64.2)])
    L.part(); L.flat(keyhole, 'T', 4)
    for k in range(3):  # dobradiças
        y = 40 + k * 18
        plate(L, [(58.6, y), (62, y - 0.3), (62, y + 2.6), (58.8, y + 2.8)], 'Y', 0.0)
    L.seams()
    return L


# ── 6. O Errante ────────────────────────────────────────────────────────────

def errante(f):
    L = Part()
    sway = [0, 0.6, 0, -0.6][f]
    wind = [0, 1, 2, 1][f]
    # tiras do manto voando para o lado
    for k in range(5):
        y = 40 + k * 7
        pts = bez((60, y), (70 + wind, y + 2 + k), (80 + wind * 1.5 - k * 2, y - 2 + k * 2))
        for i, (x_, y_) in enumerate(pts[:-1]):
            w_ = (2.4 - k * 0.2) * (1 - i / len(pts)) + 0.4
            m_ = L.mask_ellipse(x_, y_, w_ * 0.6, w_ * 0.5)
            L.part(); L.flat(m_, 'Q', 1 if i % 4 else 0)
        for x_, y_ in pts[:-3]:
            L.px1(x_, y_ - 0.5, 'Q', 2)
    # manto principal
    cloak = L.mask_poly([(48, 18), (58, 25), (62, 42), (67, 70), (70, 88), (26, 88), (29, 70), (34, 42), (38, 25)])
    L.part(); L.cylinder(cloak, 'Q', bias=-1.5, tilt=0.3, spread=2.6, dither=0.12)
    M, V = raw(L.mat), raw(L.lvl)
    for X in range(int(26 * S), int(71 * S)):  # barra rasgada
        cut = 83 + 5 * abs(math.sin(X * 0.21 + f * 0.5)) + 2 * math.sin(X * 0.07)
        for Y in range(int(cut * S), int(90 * S)):
            M[Y, X] = ''
    for k in range(6):  # dobras com luz na aresta
        x = 36 + k * 4.6 + sway
        line1(L, (x, 48 + k), (x + (k - 2.5) * 1.3, 84), 'Q', 0)
        line1(L, (x + 0.5, 48 + k), (x + 0.5 + (k - 2.5) * 1.3, 84), 'Q', 2)
    for k in range(16):  # padrão hexagonal digital na barra
        x = 30 + k * 2.4; y = 80 + (k % 2) * 1.2
        if (k + f) % 4:
            L.px1(x, y, 'Q', 4 if (k + f) % 3 else 3); L.px1(x + 0.5, y + 0.5, 'Q', 2)
    # capelete por cima dos ombros
    cap = L.mask_poly([(48, 30), (60, 34), (63, 44), (56, 47), (48, 44), (40, 47), (33, 44), (36, 34)])
    L.part(); L.cylinder(cap, 'J', bias=-0.2, tilt=0.3, **KW)
    for k in range(8):
        x = 35 + k * 3.6
        line1(L, (x, 44.5 + (k % 2)), (x + 1.2, 47 + (k % 2)), 'J', 3)
    # cinto, bolsas e alças
    plate(L, [(35, 52), (61, 52), (61.5, 54.6), (34.5, 54.6)], 'R', 0.0, axis='h')
    for x in (39, 55):
        plate(L, [(x - 2, 54), (x + 2, 54), (x + 2.2, 58.5), (x - 2.2, 58.5)], 'R', 0.15)
        L.px1(x, 55, 'Y', 3)
    orb(L, 48, 53.3, 1.6, 1.4, 'Y', 0.2)
    line1(L, (40, 33), (56, 52), 'R', 2); line1(L, (40.5, 33), (56.5, 52), 'R', 1)
    # capuz com borda iluminada e rosto vazio
    hood = L.mask_ellipse(48, 27, 10.4, 11.4)
    L.part(); L.ellipsoid(hood, 45, 23, 11, 12, 'Q', bias=-1.1, spread=2.4, dither=0.1)
    void = L.mask_ellipse(48 + sway * 0.3, 30, 6.4, 7.4)
    rim = L.mask_ellipse(48 + sway * 0.3, 30, 7.2, 8.2) & ~void & raw(hood)
    L.part(); L.flat(rim, 'Q', 3)
    L.part(); L.flat(void, 'J', 0)
    for s in (-1, 1):
        L.px1(48 + s * 2.4 + sway * 0.3, 29.5, 'Q', 4); L.px1(48 + s * 2.4 + sway * 0.3 + 0.5, 29.5, 'Q', 3)
        L.px1(48 + s * 2.4 + sway * 0.3, 30, 'Q', 2)
    # mão com lanterna de chama roxa
    limb(L, (40, 46), (33, 57), 2.4, 2.0, 'J', -0.4)
    orb(L, 32.5, 58, 2.0, 1.8, 'J', 0)
    line1(L, (32.5, 59.5), (32.5, 62), 'M', 3)
    plate(L, [(29.6, 62), (35.4, 62), (35, 63.2), (30, 63.2)], 'M', 0.2, axis='h')
    lt = L.mask_poly([(30, 63.2), (35, 63.2), (35.6, 69), (29.4, 69)])
    L.part(); L.flat(lt, 'Q', 1)
    for s in (-1, 1):
        line1(L, (32.5 + s * 2.7, 63.2), (32.5 + s * 3.0, 69), 'M', 2)
    flame = [(32.5, 64.2 - (f % 2) * 0.5), (34, 67.6), (31, 67.6)]
    L.part(); L.flat(L.mask_poly(flame), 'Q', 4)
    L.px1(32.5, 66.6, 'W', 4)
    plate(L, [(29.2, 69), (35.8, 69), (35.2, 70.6), (29.8, 70.6)], 'M', 0.1, axis='h')
    # mapa holográfico na outra mão, trilha tracejada que muda
    limb(L, (56, 46), (63, 54), 2.2, 1.9, 'J', -0.4)
    orb(L, 63.5, 55, 1.8, 1.6, 'J', 0)
    for k in range(9):
        x = 60 + k * 1.1; y = 50 - math.sin(k * 0.9 + f) * 1.6
        if (k + f) % 3:
            L.px1(x, y, 'T', 4 if k == 8 else 3)
    line1(L, (59, 52.5), (70, 52.5), 'T', 2)
    L.seams()
    if f in (1, 3):  # glitch
        rng = np.random.default_rng(f)
        for _ in range(3):
            y0 = int(rng.uniform(20, 80) * S); hh = int(rng.uniform(1.5, 3.5) * S); dx = int(rng.choice([-3, 3]) * S)
            M[y0:y0 + hh] = np.roll(M[y0:y0 + hh], dx, axis=1); V[y0:y0 + hh] = np.roll(V[y0:y0 + hh], dx, axis=1)
            L.pid[y0:y0 + hh] = np.roll(L.pid[y0:y0 + hh], dx, axis=1)
    if f == 2:
        ys, xs = np.where(M != '')
        for Y, X in zip(ys, xs):
            X2 = X - int(14 * S)
            if X2 >= 0 and M[Y, X2] == '' and (X + Y) % 2 == 0:
                M[Y, X2] = 'Q'; V[Y, X2] = 1
    return L


# ── 7. O Juiz da Bigorna ────────────────────────────────────────────────────

def juiz(f):
    L = Part()
    rng = np.random.default_rng(19)
    # chão rachado com metal derretido
    for k in range(5):
        x0 = 28 + k * 9
        pts = [(x0, 91), (x0 + 2, 92.5), (x0 + 1, 94), (x0 + 3.5, 95)]
        for a, b in zip(pts, pts[1:]):
            line1(L, a, b, 'O', 3 if (k + f) % 2 else 4)
    # vapor saindo das costas
    for s in (-1, 1):
        for k in range(3):
            t = (f + k * 1.33) % 4
            _ball(L, 48 + s * (18 + t * 0.6), 13 - t * 2.6, 1.3 + t * 0.4, 1.0 + t * 0.35, bias=-0.3 - t * 0.2, mat='W')
    # pernas com joelheiras e pistões
    for s in (-1, 1):
        limb(L, (48 + s * 7, 63), (48 + s * 10, 75), 5.2, 4.6, 'D', -0.1)
        limb(L, (48 + s * 10, 75), (48 + s * 10.5, 83), 4.4, 4.0, 'D', -0.2)
        plate(L, [(48 + s * 6.5, 72.5), (48 + s * 13.5, 72.5), (48 + s * 13, 78.5), (48 + s * 7, 78.5)], 'M', 0.1)
        L.px1(48 + s * 10, 75.5, 'O', 4)
        limb(L, (48 + s * 5, 66), (48 + s * 6.5, 80), 0.7, 0.7, 'M', 0.3)
        plate(L, [(48 + s * 3.5, 83), (48 + s * 17, 83), (48 + s * 18, 91), (48 + s * 2.5, 91)], 'D', 0.1, axis='h')
        for j in range(3):
            L.px1(48 + s * (5 + j * 4.5), 87, 'M', 4)
    # cintura
    plate(L, [(37, 60), (59, 60), (58, 66), (38, 66)], 'M', 0.0, axis='h')
    for x in np.arange(39, 58, 3):
        line1(L, (x, 60.5), (x, 65.5), 'M', 0)
    # tronco largo
    tor = L.mask_poly([(30, 29), (66, 29), (64, 46), (59, 60), (37, 60), (32, 46)])
    L.part(); L.cylinder(tor, 'D', bias=0.05, tilt=0.4, spread=3.0, dither=0.1)
    for (a, b) in (((37, 33), (59, 33)), ((34, 44), (62, 44)), ((38, 55), (58, 55))):
        line1(L, a, b, 'O', 3)
        line1(L, (a[0], a[1] + 0.5), (b[0], b[1] + 0.5), 'O', 1)
    # fornalha com grade e brasa pulsando
    furn = plate(L, [(41.5, 45), (54.5, 45), (53.5, 54), (42.5, 54)], 'M', 0.1)
    fin = L.mask_poly([(43, 46.2), (53, 46.2), (52.2, 53), (43.8, 53)])
    L.part(); L.flat(fin, 'O', 3 if f % 2 else 4)
    for x in np.arange(44, 52.5, 1.6):
        line1(L, (x, 46.2), (x, 53), 'D', 1)
    # medidor de pressão
    orb(L, 57.5, 37.5, 2.8, 2.8, 'Y', 0.1)
    L.part(); L.flat(L.mask_ellipse(57.5, 37.5, 2.0, 2.0), 'W', 3)
    a = -2.4 + f * 0.25
    line1(L, (57.5, 37.5), (57.5 + math.cos(a) * 1.8, 37.5 + math.sin(a) * 1.8), 'F', 4)
    # correntes no peito
    for k in range(9):
        L.px1(36 + k * 1.5, 36 + abs(k - 4) * 0.6, 'M', 4 if k % 2 else 2)
    # ombros com chaminés
    for s in (-1, 1):
        cx = 48 + s * 17
        plate(L, [(cx - 1.8, 15), (cx + 1.8, 15), (cx + 2.0, 27), (cx - 2.0, 27)], 'D', 0.1)
        plate(L, [(cx - 2.6, 14), (cx + 2.6, 14), (cx + 2.6, 16), (cx - 2.6, 16)], 'M', 0.2, axis='h')
        for k in range(3):
            y = 13 - ((f + k * 1.3) % 4) * 2.2
            L.px1(cx + math.sin(k + f) * 1.2, y, 'O', 4 if k % 2 else 3)
        orb(L, cx, 31, 7.4, 5.8, 'M', 0.05)
        for j in range(3):
            line1(L, (cx - 6 + j * 0.5, 31.5 + j * 1.5), (cx + 6 - j * 0.5, 31.5 + j * 1.5), 'M', 0)
    # cabeça de bigorna com chifre
    anv = L.mask_poly([(28, 13.5), (62, 13.5), (68, 15), (60, 17.2), (57, 19.5), (56, 29), (40, 29), (40, 19.5), (30, 19.5), (26, 15.5)])
    L.part(); L.cylinder(anv, 'M', bias=0.1, axis='h', spread=3.0, dither=0.08)
    line1(L, (29, 14), (61, 14), 'M', 4)
    line1(L, (40, 19.8), (56, 19.8), 'M', 0)
    face = L.mask_poly([(42, 21), (54, 21), (53, 28), (43, 28)])
    L.part(); L.flat(face, 'J', 0)
    eye_slit(L, 45, 23.4, 5, 'O', angry=2)
    eye_slit(L, 51, 23.4, 5, 'O', angry=-2)
    for x in np.arange(44, 52.5, 1.5):  # grade da boca
        line1(L, (x, 25.6), (x, 27.4), 'O', 2)
    # braço da balança
    limb(L, (31, 33), (24, 47), 4.2, 3.6, 'D', 0.1)
    joint(L, 24, 47, 2.8)
    limb(L, (24, 47), (22, 55), 3.4, 3.0, 'D', 0.0)
    orb(L, 22, 56.5, 3.0, 2.6, 'M', 0.1)
    tilt = [0, 1, 0, -1][f]
    line1(L, (22, 56), (22, 49.5), 'Y', 3)
    orb(L, 22, 49.5, 1.1, 1.1, 'Y', 0.2)
    line1(L, (12, 50.5 + tilt), (32, 50.5 - tilt), 'Y', 3)
    line1(L, (12, 51 + tilt), (32, 51 - tilt), 'Y', 1)
    for s, dy in ((-1, tilt), (1, -tilt)):
        x = 22 + s * 9.5
        for k in range(6):
            L.px1(x - 2.6 * k / 5, 51 + dy + k * 1.2, 'Y', 3 if k % 2 else 2)
            L.px1(x + 2.6 * k / 5, 51 + dy + k * 1.2, 'Y', 3 if k % 2 else 2)
        pan = L.mask_ellipse(x, 57.6 + dy, 3.6, 1.3)
        L.part(); L.ellipsoid(pan, x - 1, 57 + dy, 3.6, 1.5, 'Y', bias=0.2, **KW)
    orb(L, 31.5, 56.4 - tilt, 1.1, 1.0, 'O', glow=True)  # brasa num prato, pena de metal no outro
    line1(L, (11, 56.6 + tilt), (14, 55.6 + tilt), 'M', 4)
    # braço do martelo
    limb(L, (65, 33), (72, 47), 4.2, 3.6, 'D', 0.1)
    joint(L, 72, 47, 2.8)
    limb(L, (72, 47), (74, 56), 3.4, 3.0, 'D', 0.0)
    limb(L, (75, 52), (77, 79), 1.4, 1.4, 'D', 0.0)
    for k in range(4):
        L.px1(75.4 + k * 0.4, 60 + k * 4, 'O', 3)
    orb(L, 74.6, 57, 3.0, 2.6, 'M', 0.1)
    hm = plate(L, [(66, 77), (88, 77), (88, 90), (66, 90)], 'M', 0.0, axis='h')
    plate(L, [(64.5, 79), (66, 79), (66, 88), (64.5, 88)], 'D', 0.1)
    plate(L, [(88, 79), (89.5, 79), (89.5, 88), (88, 88)], 'D', 0.1)
    for y in (80, 87):
        line1(L, (66.5, y), (87.5, y), 'O', 3)
    for k in range(5):  # entalhe
        line1(L, (70 + k * 3, 82), (71.5 + k * 3, 85), 'O', 2)
    L.seams()
    for k, x in enumerate((37, 43, 53, 59)):  # gotas de metal derretido
        y0 = 55.5 if k in (1, 2) else 44.5
        ln = ((f + k) % 4) * 1.5
        line1(L, (x, y0), (x, y0 + 1 + ln), 'O', 4)
        if (f + k) % 4 == 3:
            L.px1(x, y0 + 3.5 + ln, 'O', 3)
    return L


BOSSES = dict(tempestade=tempestade, adiador=adiador, hidra=hidra, nevoa=nevoa, sentinela=sentinela, errante=errante, juiz=juiz)

if __name__ == '__main__':
    B.BOSSES = BOSSES
    B.render_all(only=sys.argv[1:] or None)
