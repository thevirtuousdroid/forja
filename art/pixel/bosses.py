"""Forja · os 7 chefes em pixel art cyberpunk (grade 96, saída 192), 4 quadros de animação cada.

Cada chefe é uma função boss(frame) -> Part. A composição (sombra entre partes, contorno e brilho)
é a mesma do personagem (render4). Gera bosses/<id>.png (folha 4 quadros, fundo transparente)
e prévias com fundo.
"""
import json, sys, math, os
import numpy as np
import character5  # noqa: F401  (ajuste de dithering)
from character2 import Part
from character5 import _ball
from engine import raw, SCALE as S, LIGHT
import render3, render4
from render import hx

KW = dict(spread=2.8, dither=0.12)
EXTRA = {
    'N': ['#241e3a', '#3e3566', '#6c5e9c', '#a898dc', '#e8e0ff'],   # névoa lilás
    'Q': ['#140c26', '#2c1a52', '#553596', '#9c84f6', '#e2d8ff'],   # luz roxa do Errante
}


def pal():
    p = render3.palette(dict(pele=0, corCabelo=0, corRoupa=4, olhos='azul'))
    for k, v in EXTRA.items():
        p[k] = [hx(c) for c in v]
    return p


def line1(L, a, b, mat, lvl, step=0.5):
    n = max(2, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step) + 1)
    for t in np.linspace(0, 1, n):
        L.px1(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, mat, lvl)


def bolt(L, x0, y0, x1, y1, rng, mat='B', segs=6, jit=3.0):
    pts = [(x0, y0)]
    for k in range(1, segs):
        t = k / segs
        pts.append((x0 + (x1 - x0) * t + rng.uniform(-jit, jit), y0 + (y1 - y0) * t + rng.uniform(-jit * 0.5, jit * 0.5)))
    pts.append((x1, y1))
    for a, b in zip(pts, pts[1:]):
        line1(L, (a[0] + 0.5, a[1]), (b[0] + 0.5, b[1]), mat, 2)
        line1(L, a, b, 'W', 4)
    return pts


def eye_slit(L, cx, cy, w, mat='O', angry=0):
    for k in range(-w, w + 1):
        dy = (abs(k) * angry) / max(1, w)
        L.px1(cx + k * 0.5, cy + dy * 0.5, mat, 4 if abs(k) < w * 0.6 else 3)
        L.px1(cx + k * 0.5, cy + dy * 0.5 + 0.5, mat, 2)


# ── acabamento: painéis, rebites, desgaste e luz refletida ──────────────────

METAL = ('D', 'M', 'J', 'Y', 'G', 'R')
EMIS = ('O', 'T', 'P', 'B')


def detail_pass(L, seed=0, panels=True, bounce=True, min_area=260):
    from scipy import ndimage as ndi
    M, V, pid = raw(L.mat), raw(L.lvl), L.pid
    rng = np.random.default_rng(seed)
    out = V.copy()
    for p in np.unique(pid[M != '']):
        if p == 0:
            continue
        m = (pid == p) & (M != '')
        mats = M[m]
        if len(mats) < min_area or not np.isin(mats[0], METAL):
            continue
        d = ndi.distance_transform_edt(m)
        if panels and d.max() > 9:
            g = m & (d >= 5) & (d < 6)
            out[g] = np.maximum(0, V[g] - 1)
            hl = m & (d >= 6) & (d < 7)
            up = np.zeros_like(g); up[1:] = g[:-1]
            lf = np.zeros_like(g); lf[:, 1:] = g[:, :-1]
            h_ = hl & (up | lf)
            out[h_] = np.minimum(4, V[h_] + 1)
            ys, xs = np.where(g)
            if len(ys):
                order = np.lexsort((xs, ys))
                for i in order[::23]:  # rebites
                    y, x = ys[i], xs[i]
                    if m[y + 1, x + 1]:
                        out[y, x] = 4; out[y + 1, x + 1] = max(0, V[y + 1, x + 1] - 2); out[y, x + 1] = 3; out[y + 1, x] = 2
        edge = m & (d < 2.5)
        chip = edge & (rng.random(m.shape) < 0.05)
        out[chip] = np.minimum(4, V[chip] + 1)
        ys_ = np.where(m)[0]
        y0, y1 = ys_.min(), ys_.max()
        low = m & (np.arange(m.shape[0])[:, None] > y0 + (y1 - y0) * 0.7) & (rng.random(m.shape) < 0.06)
        out[low] = np.maximum(0, V[low] - 1)
        scr = m & (d > 3) & (rng.random(m.shape) < 0.004)  # arranhões curtos
        for y, x in zip(*np.where(scr)):
            for k in range(3):
                if m[y + k, x + k]:
                    out[y + k, x + k] = min(4, V[y + k, x + k] + 1)
    V[:] = out
    if bounce:  # luz das partes acesas refletida no metal vizinho
        for e in EMIS:
            em = M == e
            if em.sum() < 6:
                continue
            dist = ndi.distance_transform_edt(~em)
            near = np.isin(M, METAL) & (dist <= 3) & (dist > 0)
            I = np.indices(M.shape)
            pat = ((I[0] % 2) == 0) & ((I[1] % 2) == 0) | ((dist <= 1.5) & ((I.sum(0) % 2) == 0))
            pick = near & pat & (V >= 1)
            M[pick] = e
            V[pick] = np.where(dist[pick] <= 1.5, 1, 0)
    return L


# ── 1. A Tempestade Interna ─────────────────────────────────────────────────

def tempestade(f):
    """Androide flutuante com o cérebro exposto numa cúpula de vidro, nuvem de destroços e raios."""
    L = Part()
    rng = np.random.default_rng(100 + f)
    bob = [0, -0.5, -1, -0.5][f]
    # nuvem de tempestade atrás da cabeça (bolas escuras que giram)
    for k in range(14):
        a = k / 14 * 2 * math.pi + f * 0.22
        _ball(L, 48 + math.cos(a) * (16 + (k % 3)), 30 + bob + math.sin(a) * (8 + (k % 2)), 4.6 - (k % 3) * 0.5, 3.8, bias=-1.0, mat='B')
    # vórtice de cabos no lugar das pernas
    for k in range(7):
        y = 62 + k * 3.6 + bob
        w = 11 - k * 1.4
        ring = L.mask_ellipse(48 + math.sin(f * 1.5 + k) * 0.8, y, w, 1.8)
        L.part(); L.ellipsoid(ring, 46, y - 1, w + 1, 2.2, 'J', bias=0.1, **KW)
        for j in range(3):
            a = (j / 3 + f / 12 + k * 0.13) * 2 * math.pi
            L.px1(48 + math.cos(a) * w * 0.9, y + math.sin(a) * 1.2, 'B', 4)
    # braços abertos, garras
    for s in (-1, 1):
        sh = (48 + s * 13, 46 + bob)
        el = (48 + s * 20, 54 + bob)
        hd = (48 + s * 25, 63 + bob)
        L.part(); L.capsule(sh, el, 2.6, 2.2, 'D', bias=0.1, **KW)
        L.part(); L.capsule(el, hd, 2.2, 1.8, 'D', bias=0.0, **KW)
        for j in (-1, 0, 1):
            L.part(); L.capsule(hd, (hd[0] + s * 1.4 + j * 1.6, hd[1] + 4.2), 0.7, 0.5, 'M', bias=0.2, **KW)
        orb = L.mask_ellipse(*sh, 4.4, 4.0)
        L.part(); L.ellipsoid(orb, sh[0] - 1.2, sh[1] - 1.2, 4.4, 4.0, 'M', bias=0.2, **KW)
        L.px(int(sh[0]), int(sh[1]), 'B', 4)
    # tronco
    chest = L.mask_ellipse(48, 52 + bob, 12.5, 11)
    L.part(); L.ellipsoid(chest, 45, 47 + bob, 13, 12, 'D', bias=0.05, spread=2.9, dither=0.1)
    for k in range(3):  # costelas
        y = 55 + k * 2.6 + bob
        line1(L, (40 + k, y), (56 - k, y), 'D', 0)
    core = L.mask_ellipse(48, 48 + bob, 3.6, 3.6)
    L.part(); L.ellipsoid(core, 47, 47 + bob, 3.6, 3.6, 'O', bias=0.9, spread=1.6, dither=0.05)
    # pescoço e cúpula com o cérebro
    L.part(); L.capsule((48, 42 + bob), (48, 37 + bob), 3.0, 2.6, 'M', bias=0.0, **KW)
    dome = L.mask_ellipse(48, 30 + bob, 8.2, 7.4)
    L.part(); L.ellipsoid(dome, 45.6, 27 + bob, 8.6, 8, 'T', bias=-0.9, spread=2.2, dither=0.08)
    brain = L.mask_ellipse(48, 31 + bob, 5.6, 4.6)
    L.part(); L.ellipsoid(brain, 46.5, 29.5 + bob, 5.8, 5, 'P', bias=0.2, spread=2.4, dither=0.1)
    for k in range(5):  # sulcos do cérebro
        a = 0.3 + k * 0.55
        line1(L, (44 + k * 2, 28 + bob + (k % 2)), (45 + k * 2, 33 + bob - (k % 2)), 'P', 1)
    for (x, y) in ((43.5, 25.5), (44, 25), (45, 24.6)):
        L.px1(x, y + bob, 'W', 4)  # reflexo do vidro
    base = L.mask_poly([(39, 35 + bob), (57, 35 + bob), (56, 38 + bob), (40, 38 + bob)])
    L.part(); L.cylinder(base, 'M', bias=0.2, axis='h', **KW)
    for x in range(41, 56, 3):
        L.px1(x, 36.5 + bob, 'O', 4)
    L.seams()
    # raios: saem da cúpula e das mãos
    for _ in range(3 + f % 2):
        a = rng.uniform(0, 2 * math.pi)
        bolt(L, 48 + math.cos(a) * 7, 30 + bob + math.sin(a) * 6, 48 + math.cos(a) * 24, 30 + math.sin(a) * 18, rng, segs=5, jit=2.4)
    for s in (-1, 1):
        if (f + (s > 0)) % 2 == 0:
            bolt(L, 48 + s * 25, 68 + bob, 48 + s * rng.uniform(16, 30), 90, rng, segs=5, jit=2.5)
    return L


# ── 2. O Adiador ────────────────────────────────────────────────────────────

def adiador(f):
    """Máquina corcunda sentada numa pilha de tarefas, com a ampulheta travada na barriga e visor sonolento."""
    L = Part()
    rng = np.random.default_rng(7)
    # pilha de papéis e caixas (tarefas adiadas)
    for k in range(16):
        x = 22 + rng.uniform(0, 52); y = 84 + rng.uniform(0, 7)
        w = rng.uniform(4, 7); h = rng.uniform(2.5, 4)
        pg = L.mask_poly([(x - w / 2, y - h / 2), (x + w / 2, y - h / 2 + rng.uniform(-1, 1)), (x + w / 2, y + h / 2), (x - w / 2, y + h / 2)])
        L.part(); L.flat(pg, 'W' if k % 3 else 'R', 2 if k % 2 else 3)
        if k % 3:
            for j in range(2):
                line1(L, (x - w / 2 + 1, y - h / 2 + 1 + j), (x + w / 2 - 1.5, y - h / 2 + 1 + j), 'W', 0)
        else:
            L.px(int(x), int(y), 'O', 3)
    # pernas dobradas
    for s in (-1, 1):
        L.part(); L.capsule((48 + s * 9, 72), (48 + s * 17, 80), 5.0, 4.4, 'D', bias=-0.1, **KW)
        L.part(); L.capsule((48 + s * 17, 80), (48 + s * 13, 88), 4.0, 3.6, 'D', bias=-0.2, **KW)
    # corpo corcunda
    back = L.mask_ellipse(48, 56, 20, 19)
    back[int(75):, :] = False
    L.part(); L.ellipsoid(back, 42, 46, 21, 20, 'D', bias=0.0, spread=3.0, dither=0.12)
    for (x, y, r_) in ((34, 50, 3), (60, 60, 2.6), (40, 66, 2.2)):  # ferrugem
        rm = L.mask_ellipse(x, y, r_, r_ * 0.8) & back
        L.flat(rm, 'R', 2)
    for k in range(5):  # rebites no arco das costas
        a = math.pi * (1.1 + k * 0.2)
        L.px(int(48 + math.cos(a) * 18), int(56 + math.sin(a) * 17), 'M', 4)
    # relógio no ombro
    ck = L.mask_ellipse(63, 42, 5, 5)
    L.part(); L.ellipsoid(ck, 62, 41, 5, 5, 'Y', bias=0.1, **KW)
    face = L.mask_ellipse(63, 42, 3.6, 3.6)
    L.part(); L.flat(face, 'W', 3)
    line1(L, (63, 42), (63, 39), 'K', 0)
    ang = -math.pi / 2 + f * 0.05  # o ponteiro quase não anda
    line1(L, (63, 42), (63 + math.cos(ang + 1.9) * 2.6, 42 + math.sin(ang + 1.9) * 2.6), 'O', 2)
    # ampulheta na barriga
    for yy in (52, 71):
        cap = L.mask_poly([(40, yy - 1.4), (56, yy - 1.4), (55, yy + 1.4), (41, yy + 1.4)])
        L.part(); L.cylinder(cap, 'Y', bias=0.2, axis='h', **KW)
    for s in (-1, 1):
        L.part(); L.capsule((48 + s * 7, 53), (48 + s * 7, 70), 0.8, 0.8, 'Y', bias=0.1, **KW)
    glass = L.mask_poly([(42.5, 53.5), (53.5, 53.5), (49.2, 61.5), (53.5, 69.5), (42.5, 69.5), (46.8, 61.5)])
    L.part(); L.flat(glass, 'T', 1)
    sand = L.mask_poly([(43.5, 54.5), (52.5, 54.5), (49.5, 59.5), (46.5, 59.5)])
    L.part(); L.cylinder(sand, 'O', bias=0.2, axis='h', **KW)
    L.px1(48, 61.5 - (0.5 if f % 2 else 0), 'O', 4)  # o grão que nunca cai
    for (x, y) in ((44, 55), (44.5, 66)):
        L.px1(x, y, 'T', 4)
    for (x, y) in ((45, 64), (51, 66), (47, 67.5)):  # trincas de golpes
        line1(L, (x, y), (x + 1.5, y + 1.6), 'T', 4)
    # braços pendurados até o chão
    for s in (-1, 1):
        sh = (48 + s * 16, 44)
        L.part(); L.capsule(sh, (48 + s * 23, 64), 4.2, 3.6, 'D', bias=0.1, **KW)
        L.part(); L.capsule((48 + s * 23, 64), (48 + s * 24, 82), 3.4, 3.0, 'D', bias=0.0, **KW)
        hd = L.mask_ellipse(48 + s * 24, 84, 4.4, 3.2)
        L.part(); L.ellipsoid(hd, 48 + s * 24 - 1, 83, 4.4, 3.2, 'M', bias=0.1, **KW)
        L.part(); ell_ = L.mask_ellipse(*sh, 6, 5)
        L.ellipsoid(ell_, sh[0] - 2, sh[1] - 2, 6, 5, 'M', bias=0.15, **KW)
    # cabeça caída para frente, visor sonolento
    hy = 38 + [0, 0.5, 1, 0.5][f]
    head = L.mask_ellipse(48, hy, 7.4, 6)
    L.part(); L.ellipsoid(head, 46, hy - 2, 7.6, 6.4, 'D', bias=0.2, **KW)
    vis = L.mask_poly([(42, hy - 0.5), (54, hy - 0.5), (53, hy + 2.6), (43, hy + 2.6)])
    L.part(); L.flat(vis, 'J', 0)
    lid = 1 if f in (1, 2) else 0  # pálpebra pesada
    for s in (-1, 1):
        for k in range(-3, 4):
            L.px1(48 + s * 2.8 + k * 0.5, hy + 1.2 + lid * 0.5, 'O', 4 if abs(k) < 2 else 3)
    L.seams()
    for k in range(3):  # Z z z subindo
        y = 30 - ((f + k * 1.4) % 4) * 3 - k * 2
        x = 58 + k * 4
        sz = 1.6 - k * 0.3
        line1(L, (x, y), (x + sz * 2, y), 'T', 4); line1(L, (x + sz * 2, y), (x, y + sz * 2), 'T', 4); line1(L, (x, y + sz * 2), (x + sz * 2, y + sz * 2), 'T', 4)
    return L


# ── 3. A Hidra das Notificações (protótipo aprovado, refeito na grade nova) ─

def hidra(f):
    import boss
    L = Part()
    src = boss.hydra(f)
    raw(L.mat)[:] = raw(src.mat); raw(L.lvl)[:] = raw(src.lvl)
    return L


# ── 4. A Névoa do Esquecimento ──────────────────────────────────────────────

def nevoa(f):
    """Massa de névoa que se desfaz nas bordas, olhos vazios e páginas virando poeira."""
    L = Part()
    rng = np.random.default_rng(4)
    bob = [0, -0.6, -1, -0.6][f]
    body = L.mask_ellipse(48, 46 + bob, 19, 23) | L.mask_ellipse(48, 62 + bob, 15, 10)
    L.part(); L.ellipsoid(body, 44, 40 + bob, 20, 26, 'N', bias=0.0, spread=2.6, dither=0.1)
    M, V = raw(L.mat), raw(L.lvl)
    ys, xs = np.where(M == 'N')
    for Y, X in zip(ys, xs):  # redemoinhos de fumaça (faixas onduladas)
        x, y = X / S, Y / S
        w = math.sin(x * 0.55 + math.sin(y * 0.35 + f * 0.8) * 2.2) + math.sin(y * 0.42 - x * 0.2 + f * 0.6)
        if w > 1.15:
            V[Y, X] = min(4, V[Y, X] + 1)
        elif w < -1.2:
            V[Y, X] = max(0, V[Y, X] - 1)
    for Y, X in zip(ys, xs):  # bordas se desfazendo (muda a cada quadro)
        d = math.hypot(X / S - 48, (Y / S - 48) * 0.78) / 20
        if d > 0.78 and ((X * 7 + Y * 3 + f * 5) % 11) < (d - 0.78) * 70:
            M[Y, X] = ''
    for k in range(18):  # fiapos soltos em volta
        a = k / 18 * 2 * math.pi + f * 0.15
        rr = 22 + (k % 3) * 2
        L.px1(48 + math.cos(a) * rr * 0.85, 46 + bob + math.sin(a) * rr, 'N', 3 if k % 2 else 2)
    # cauda em fios no chão
    for k in range(5):
        x0 = 36 + k * 6
        for t in np.linspace(0, 1, 18):
            x = x0 + math.sin(t * 5 + f + k) * 1.4; y = 70 + bob + t * 18
            if ((int(t * 18) + f + k) % 5) != 0:
                L.px1(x, y, 'N', 3 if t < 0.5 else 2)
                L.px1(x + 0.5, y, 'N', 2)
    # olhos ocos e sorriso
    for s in (-1, 1):
        e = L.mask_ellipse(48 + s * 6, 42 + bob, 2.6, 3.4)
        L.part(); L.flat(e, 'N', 0)
        L.px1(48 + s * 6 - 0.5, 41 + bob, 'W', 4 if f != 2 else 3)
    for k in range(-12, 13):
        x = 48 + k * 0.5; y = 52 + bob + (144 - k * k) / 80
        L.px1(x, y, 'N', 0); L.px1(x, y + 0.5, 'N', 0)
    # páginas flutuando e virando pó
    for k, (x, y, ang) in enumerate(((22, 30, -0.3), (73, 36, 0.25), (26, 64, 0.4), (70, 66, -0.2))):
        y += math.sin(f * math.pi / 2 + k) * 1.2
        c, s_ = math.cos(ang), math.sin(ang)
        corners = [(x + c * dx - s_ * dy, y + s_ * dx + c * dy) for dx, dy in ((-3, -4), (3, -4), (3, 4), (-3, 4))]
        pg = L.mask_poly(corners)
        L.part(); L.flat(pg, 'W', 3)
        for j in range(4):
            a_ = (x - 2, y - 2.4 + j * 1.5); b_ = (x + 1.6 - (j % 2), y - 2.4 + j * 1.5)
            line1(L, (x + c * (a_[0] - x) - s_ * (a_[1] - y), y + s_ * (a_[0] - x) + c * (a_[1] - y)),
                  (x + c * (b_[0] - x) - s_ * (b_[1] - y), y + s_ * (b_[0] - x) + c * (b_[1] - y)), 'N', 1)
        Mm = raw(pg); ys_, xs_ = np.where(Mm)
        for Y, X in zip(ys_, xs_):  # canto se desmanchando
            if (X + Y + f) % 3 == 0 and (Y / S > y + 1.5):
                raw(L.mat)[Y, X] = ''
        for j in range(5):  # pó saindo
            L.px1(x + 3 + j * 0.8 + f * 0.3, y + 3.5 + math.sin(j + f) * 0.8, 'W', 2)
    L.seams()
    return L


# ── 5. A Sentinela de Pedra ─────────────────────────────────────────────────

def sentinela(f):
    """Golem blindado de pedra e metal, escudo de laje com circuitos, rachaduras acesas, olho único."""
    L = Part()
    glow = [3, 4, 4, 3][f]
    # pernas grossas
    for s in (-1, 1):
        L.part(); L.cylinder(L.mask_poly([(48 + s * 4, 66), (48 + s * 13, 66), (48 + s * 14, 84), (48 + s * 3, 84)]), 'M', bias=-0.9, **KW)
        L.part(); L.cylinder(L.mask_poly([(48 + s * 2, 84), (48 + s * 16, 84), (48 + s * 17, 91), (48 + s * 1, 91)]), 'D', bias=0.1, axis='h', **KW)
    # tronco em blocos
    tor = L.mask_poly([(30, 36), (66, 36), (70, 46), (62, 66), (34, 66), (26, 46)])
    L.part(); L.cylinder(tor, 'M', bias=-0.9, tilt=0.4, spread=3.0, dither=0.1)
    for (a, b) in (((30, 46), (66, 46)), ((34, 56), (62, 56)), ((48, 36), (48, 66))):
        line1(L, a, b, 'M', 0)
    Mt, Vt = raw(L.mat), raw(L.lvl)
    for Y, X in zip(*np.where(Mt == 'M')):  # textura de pedra
        n = (X * 13 + Y * 7) % 17
        if n == 0 and Vt[Y, X] > 0: Vt[Y, X] -= 1
        elif n == 5 and Vt[Y, X] < 4: Vt[Y, X] += 1
    # musgo de pedra-verde
    for (x, y) in ((33, 40), (35, 39), (60, 62), (62, 61), (38, 64)):
        L.px(x, y, 'G', 3)
    # rachaduras acesas
    for pts in (((40, 38), (43, 42), (41, 46), (44, 50)), ((56, 48), (53, 52), (55, 56), (52, 61))):
        for a, b in zip(pts, pts[1:]):
            line1(L, a, b, 'T', glow)
    # braço esquerdo com punho
    L.part(); L.capsule((28, 42), (20, 58), 5.6, 4.8, 'M', bias=-0.7, **KW)
    fist = L.mask_ellipse(19, 63, 6, 5.4)
    L.part(); L.ellipsoid(fist, 17, 61, 6, 5.4, 'D', bias=0.2, **KW)
    for k in range(3):
        line1(L, (15 + k * 3, 60), (15 + k * 3, 65), 'D', 0)
    # ombreiras
    for s in (-1, 1):
        sp = L.mask_poly([(48 + s * 14, 31), (48 + s * 24, 33), (48 + s * 25, 42), (48 + s * 15, 42)])
        L.part(); L.cylinder(sp, 'D', bias=0.2, **KW)
        L.px(int(48 + s * 20), 36, 'T', glow)
    # cabeça encaixada entre os ombros
    hd = L.mask_poly([(41, 26), (55, 26), (57, 36), (39, 36)])
    L.part(); L.cylinder(hd, 'D', bias=0.15, **KW)
    eye_slit(L, 48, 31, 6, 'T')
    # escudo de laje à direita
    sh = L.mask_poly([(60, 34), (80, 32), (82, 82), (64, 86), (60, 80)])
    L.part(); L.cylinder(sh, 'M', bias=-0.8, tilt=-0.3, spread=3.0, dither=0.1)
    edge = sh & ~L.mask_poly([(62, 36), (78, 34.5), (80, 80), (65, 83.5), (62, 79)])
    L.flat(edge, 'D', 3)
    for (a, b) in (((71, 40), (71, 76)), ((71, 50), (66, 54)), ((71, 50), (76, 54)), ((71, 64), (66, 68)), ((71, 64), (76, 68))):
        line1(L, a, b, 'T', glow if a[1] < 60 else glow - 1)
    Mt[:], Vt[:] = raw(L.mat), raw(L.lvl)
    dk = (raw(L.mat) == 'M') & (raw(L.lvl) > 0)
    raw(L.lvl)[dk] -= 1  # pedra mais escura
    core = L.mask_ellipse(71, 58, 2.6, 2.6)
    L.part(); L.ellipsoid(core, 70.4, 57.4, 2.6, 2.6, 'T', bias=0.9, spread=1.6, dither=0.05)
    L.seams()
    return L


# ── 6. O Errante ────────────────────────────────────────────────────────────

def errante(f):
    """Andarilho encapuzado de manto rasgado, rosto vazio com dois pontos de luz; falha e se repete (glitch)."""
    L = Part()
    sway = [0, 0.6, 0, -0.6][f]
    # manto
    cloak = L.mask_poly([(48, 18), (58, 26), (62, 44), (68, 72), (70, 88), (26, 88), (28, 72), (34, 44), (38, 26)])
    L.part(); L.cylinder(cloak, 'Q', bias=-1.5, tilt=0.3, spread=2.6, dither=0.12)
    M, V = raw(L.mat), raw(L.lvl)
    for X in range(int(26 * S), int(71 * S)):  # barra rasgada
        cut = 84 + 4 * abs(math.sin(X * 0.21 + f)) + 2 * math.sin(X * 0.07)
        for Y in range(int(cut * S), int(90 * S)):
            M[Y, X] = ''
    for k in range(5):  # dobras
        x = 38 + k * 5 + sway
        line1(L, (x, 48 + k), (x + (k - 2) * 1.2, 84), 'Q', 0)
    for k in range(10):  # runas que piscam no manto
        x = 34 + k * 3.2; y = 76 + (k % 3) * 2
        if (k + f) % 3:
            L.px1(x, y, 'Q', 4); L.px1(x + 0.5, y + 0.5, 'Q', 3)
    belt = L.mask_poly([(36, 50), (60, 50), (60.5, 52.4), (35.5, 52.4)])
    L.part(); L.cylinder(belt, 'R', bias=0.0, axis='h', **KW)
    L.px(48, 51, 'Y', 3)
    # capuz
    hood = L.mask_ellipse(48, 27, 10, 11)
    L.part(); L.ellipsoid(hood, 45, 23, 11, 12, 'Q', bias=-1.1, spread=2.4, dither=0.1)
    void = L.mask_ellipse(48 + sway * 0.3, 30, 6.2, 7.2)
    L.part(); L.flat(void, 'J', 0)
    for s in (-1, 1):
        L.px1(48 + s * 2.4 + sway * 0.3, 29.5, 'Q', 4); L.px1(48 + s * 2.4 + sway * 0.3 + 0.5, 29.5, 'Q', 3)
    # mão segurando uma bússola que não para de girar
    L.part(); L.capsule((40, 46), (34, 58), 2.4, 2.0, 'Q', bias=-0.5, **KW)
    cm = L.mask_ellipse(32, 61, 3.6, 3.6)
    L.part(); L.ellipsoid(cm, 31, 60, 3.6, 3.6, 'Y', bias=0.1, **KW)
    L.part(); L.flat(L.mask_ellipse(32, 61, 2.4, 2.4), 'J', 1)
    a = f * 1.9
    line1(L, (32, 61), (32 + math.cos(a) * 2.2, 61 + math.sin(a) * 2.2), 'Q', 4)
    L.seams()
    # glitch: fatias deslocadas e eco
    if f in (1, 3):
        rng = np.random.default_rng(f)
        for _ in range(3):
            y0 = int(rng.uniform(20, 80) * S); hh = int(rng.uniform(1.5, 3.5) * S); dx = int(rng.choice([-3, 3]) * S)
            M[y0:y0 + hh] = np.roll(M[y0:y0 + hh], dx, axis=1); V[y0:y0 + hh] = np.roll(V[y0:y0 + hh], dx, axis=1)
    if f == 2:  # eco do Errante, onde ele estava
        ys, xs = np.where(M != '')
        for Y, X in zip(ys, xs):
            X2 = X - int(12 * S)
            if X2 >= 0 and M[Y, X2] == '' and (X + Y) % 2 == 0:
                M[Y, X2] = 'Q'; V[Y, X2] = 1
    return L


# ── 7. O Juiz da Bigorna ────────────────────────────────────────────────────

def juiz(f):
    """Colosso de forja: cabeça em forma de bigorna, juntas de metal derretido, balança e martelo."""
    L = Part()
    rng = np.random.default_rng(9)
    # pernas
    for s in (-1, 1):
        L.part(); L.capsule((48 + s * 7, 64), (48 + s * 10, 80), 5.0, 4.4, 'D', bias=-0.1, **KW)
        L.part(); L.cylinder(L.mask_poly([(48 + s * 4, 80), (48 + s * 16, 80), (48 + s * 17, 91), (48 + s * 3, 91)]), 'D', bias=0.1, axis='h', **KW)
        line1(L, (48 + s * 7, 71), (48 + s * 11, 72), 'O', 3)
    # tronco
    tor = L.mask_poly([(32, 30), (64, 30), (61, 52), (56, 66), (40, 66), (35, 52)])
    L.part(); L.cylinder(tor, 'D', bias=0.05, tilt=0.4, spread=3.0, dither=0.1)
    for (a, b) in (((40, 34), (56, 34)), ((37, 44), (59, 44)), ((40, 56), (56, 56))):
        line1(L, a, b, 'O', 3)  # juntas incandescentes
    furn = L.mask_poly([(43, 46), (53, 46), (52, 54), (44, 54)])
    L.part(); L.flat(furn, 'O', 3)
    for x in np.arange(44, 52.5, 1.5):
        line1(L, (x, 46.5), (x, 53.5), 'D', 1)
    # ombros com chaminés soltando faíscas
    for s in (-1, 1):
        sp = L.mask_ellipse(48 + s * 17, 31, 7, 5.6)
        L.part(); L.ellipsoid(sp, 48 + s * 17 - 2, 29, 7, 5.6, 'M', bias=0.05, **KW)
        L.part(); L.cylinder(L.mask_poly([(48 + s * 17 - 1.6, 18), (48 + s * 17 + 1.6, 18), (48 + s * 17 + 1.8, 28), (48 + s * 17 - 1.8, 28)]), 'D', bias=0.1, **KW)
        for k in range(3):
            y = 16 - ((f + k * 1.3) % 4) * 2.5
            L.px1(48 + s * 17 + math.sin(k + f) * 1.4, y, 'O', 4 if k % 2 else 3)
    # cabeça de bigorna
    anv = L.mask_poly([(32, 14), (66, 14), (60, 19.5), (56, 19.5), (56, 29), (40, 29), (40, 19.5), (30, 19.5)])
    L.part(); L.cylinder(anv, 'M', bias=0.1, axis='h', spread=3.0, dither=0.08)
    eye_slit(L, 44.5, 23.2, 5, 'O', angry=2)
    eye_slit(L, 51.5, 23.2, 5, 'O', angry=-2)
    line1(L, (32, 15), (64, 15), 'M', 4)
    # braço com a balança (esquerda)
    L.part(); L.capsule((31, 34), (24, 48), 4.0, 3.4, 'D', bias=0.1, **KW)
    L.part(); L.capsule((24, 48), (22, 56), 3.2, 2.8, 'D', bias=0.0, **KW)
    tilt = [0, 1, 0, -1][f]
    line1(L, (22, 56), (22, 50), 'Y', 3)
    line1(L, (13, 51 + tilt), (31, 51 - tilt), 'Y', 3)
    for s, dy in ((-1, tilt), (1, -tilt)):
        x = 22 + s * 9
        line1(L, (x, 51 + dy), (x - 2.4, 57 + dy), 'Y', 2); line1(L, (x, 51 + dy), (x + 2.4, 57 + dy), 'Y', 2)
        pan = L.mask_ellipse(x, 57.6 + dy, 3.4, 1.2)
        L.part(); L.ellipsoid(pan, x - 1, 57 + dy, 3.4, 1.4, 'Y', bias=0.2, **KW)
    L.px1(31, 56 + tilt * -1, 'O', 4)  # brasa num dos pratos
    # braço com o martelo (direita), cabeça apoiada no chão
    L.part(); L.capsule((65, 34), (72, 48), 4.0, 3.4, 'D', bias=0.1, **KW)
    L.part(); L.capsule((72, 48), (74, 58), 3.2, 2.8, 'D', bias=0.0, **KW)
    L.part(); L.capsule((74, 54), (76, 80), 1.3, 1.3, 'D', bias=0.0, **KW)
    hm = L.mask_poly([(68, 78), (86, 78), (86, 90), (68, 90)])
    L.part(); L.cylinder(hm, 'M', bias=0.1, axis='h', **KW)
    for y in (81, 87):
        line1(L, (68.5, y), (85.5, y), 'O', 3)
    L.seams()
    # metal derretido pingando das juntas
    for k, x in enumerate((38, 45, 52, 58)):
        y0 = 56 if k in (1, 2) else 44
        ln = ((f + k) % 4) * 1.6
        line1(L, (x, y0), (x, y0 + 1 + ln), 'O', 4)
        if (f + k) % 4 == 3:
            L.px1(x, y0 + 3.5 + ln, 'O', 3)
    for k in range(6):  # brasas no chão
        L.px1(30 + rng.uniform(0, 40), 91 + rng.uniform(0, 1.5), 'O', 3 if (k + f) % 2 else 4)
    return L


BOSSES = dict(tempestade=tempestade, adiador=adiador, hidra=hidra, nevoa=nevoa, sentinela=sentinela, errante=errante, juiz=juiz)


def render_all(outdir='bosses_px', only=None):
    from PIL import Image
    os.makedirs(outdir, exist_ok=True)
    p = pal()
    sheets = {}
    for bid, fn in BOSSES.items():
        if only and bid not in only:
            continue
        frames = []
        for fr in range(4):
            Lb = detail_pass(fn(fr), seed=fr)
            rgba = render4.compose({'b': {'px': Lb.encode()}}, ['b'], p)
            frames.append(rgba)
        sheet = np.concatenate(frames, axis=1)
        Image.fromarray(np.uint8(np.dstack([sheet[..., :3], sheet[..., 3] * 255])), 'RGBA').save(f'{outdir}/{bid}.png')
        render4.image(frames[0], 2).save(f'{outdir}/{bid}_prev.png')
        sheets[bid] = frames
        print(bid, 'ok')
    return sheets


if __name__ == '__main__':
    render_all(only=sys.argv[1:] or None)
