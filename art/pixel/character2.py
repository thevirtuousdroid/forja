"""Personagem do Forja em pixel art, versão 2 (96x96): corpo construído por partes, proporção adulta (~1:5,5).

Cada parte (tórax, cintura, quadril, deltoides, braço, antebraço, coxa, panturrilha) tem volume próprio,
e as junções entre partes ganham uma linha de sombra, como em pixel art desenhada à mão.
"""
import json, sys
import numpy as np
from engine import Layer, LIGHT, raw, SCALE

N = 96


class Part(Layer):
    """Camada que lembra qual parte pintou cada pixel, para marcar as junções."""
    def __init__(self):
        super().__init__(N, N)
        self.pid = np.zeros((self.h, self.w), int)
        self.cur = 0

    def part(self):
        self.cur += 1
        return self

    def _put(self, mask, mat, lvl):
        super()._put(mask, mat, lvl)
        self.pid[raw(mask)] = self.cur

    def seams(self, strength=1):
        """Junção entre partes: o pixel da parte de cima fica um tom mais escuro na borda (baixo e lados)."""
        on = raw(self.mat) != ''
        pid = self.pid
        lvl = raw(self.lvl)
        hit = np.zeros_like(on)
        for dy, dx in ((1, 0), (0, -1), (0, 1)):
            nb_on = np.zeros_like(on); nb_pid = np.zeros_like(pid)
            ys = slice(max(dy, 0), self.h + min(dy, 0)); yd = slice(max(-dy, 0), self.h + min(-dy, 0))
            xs = slice(max(dx, 0), self.w + min(dx, 0)); xd = slice(max(-dx, 0), self.w + min(-dx, 0))
            nb_on[yd, xd] = on[ys, xs]; nb_pid[yd, xd] = pid[ys, xs]
            hit |= on & nb_on & (nb_pid != pid) & (pid > nb_pid)
        lvl[hit] = np.maximum(0, lvl[hit] - strength)
        # bisel: a borda de cima e da esquerda de cada peça pega a luz (1 pixel fino)
        lit = np.zeros_like(on)
        for dy, dx in ((-1, 0), (0, -1)):
            nb_on = np.zeros_like(on); nb_pid = np.zeros_like(pid)
            ys = slice(max(dy, 0), self.h + min(dy, 0)); yd = slice(max(-dy, 0), self.h + min(-dy, 0))
            xs = slice(max(dx, 0), self.w + min(dx, 0)); xd = slice(max(-dx, 0), self.w + min(-dx, 0))
            nb_on[yd, xd] = on[ys, xs]; nb_pid[yd, xd] = pid[ys, xs]
            lit |= on & (~nb_on | (nb_pid != pid)) & ~hit
        mats = raw(self.mat)
        keep = lit & ~np.isin(mats, ['O', 'T', 'P', 'W', 'K', 'I'])
        lvl[keep] = np.minimum(4, lvl[keep] + 1)


def mirror(p):
    return (96 - p[0], p[1])


RIG = {
    'm': dict(head=(48, 14, 7.4, 8.6), chin=(4.0, 23.2), neck=((48, 20), (48, 28), 3.4, 3.9),
              sh=(37.5, 30.5), delt=(4.7, 4.1), chest=(48, 35, 10.6, 7.4), abd=(48, 44, 8.0, 5.8), pelv=(48, 51, 9.0, 4.8),
              up=((36.4, 31.5), (34.6, 44), 3.8, 3.0), fore=((34.6, 44), (34.2, 55), 3.1, 2.3), hand=(34.2, 57.8, 2.5, 3.2),
              thigh=((43.6, 52), (43.4, 70), 5.0, 3.6), calf=((43.4, 70), (43.6, 76.5), 3.8, 3.6), shin=((43.6, 76.5), (43.6, 83), 3.6, 2.6),
              foot=(42.6, 89.6, 4.6, 2.4), eye_y=15, female=False),
    'f': dict(head=(48, 15, 7.0, 8.2), chin=(3.0, 23.6), neck=((48, 21), (48, 29), 2.7, 3.1),
              sh=(40.2, 32), delt=(3.7, 3.4), chest=(48, 36.5, 8.6, 6.6), abd=(48, 44.2, 6.2, 5.2), pelv=(48, 51.2, 9.8, 5.4),
              up=((39.3, 33.2), (37.8, 44), 3.0, 2.5), fore=((37.8, 44), (37.4, 54.5), 2.5, 1.9), hand=(37.4, 57.2, 2.0, 2.7),
              thigh=((44.0, 52.5), (44.4, 70), 5.1, 3.3), calf=((44.4, 70), (44.6, 76), 3.4, 3.2), shin=((44.6, 76), (44.7, 83), 3.2, 2.2),
              foot=(44.0, 89.6, 3.8, 2.2), eye_y=15, female=True),
}


def ell(L, cx, cy, rx, ry, mat, **kw):
    m = L.mask_ellipse(cx, cy, rx, ry)
    L.ellipsoid(m, cx - rx * 0.12, cy - ry * 0.15, rx * 1.05, ry * 1.08, mat, **kw)
    return m


# ── corpo (traje) ───────────────────────────────────────────────────────────

def body(r):
    L = Part()
    kw = dict(spread=2.8, dither=0.16)
    # pernas
    for side in (0, 1):
        f = (lambda p: p) if side == 0 else mirror
        (a, b, r0, r1) = r['thigh']; L.part().capsule(f(a), f(b), r0, r1, 'C', bias=-0.5, **kw)
        (a, b, r0, r1) = r['calf']; L.part().capsule(f(a), f(b), r0, r1, 'C', bias=-0.6, **kw)
        (a, b, r0, r1) = r['shin']; L.capsule(f(a), f(b), r0, r1, 'C', bias=-0.6, **kw)
        # joelheira
        kx, ky = f(r['thigh'][1])
        L.part(); ell(L, kx, ky + 0.5, 2.6, 2.4, 'D', bias=0.3, **kw)
        # bota
        sx, sy = f(r['shin'][0])
        ex, ey = f(r['shin'][1])
        boot = L.mask_poly([(ex - 3.6, 79.5), (ex + 3.6, 79.5), (ex + 3.9, 88), (ex - 3.9, 88)])
        L.part(); L.cylinder(boot, 'D', bias=0.0, **kw)
        fx, fy, frx, fry = r['foot']
        fx = f((fx, fy))[0]
        L.part(); ell(L, fx, fy, frx, fry, 'D', bias=0.1, **kw)
        for x in range(int(ex - 3.5), int(ex + 4)):
            L.px(x, 80, 'M', 2)
        L.px(int(fx + (-2 if side == 0 else 2)), int(fy) - 1, 'M', 4)
    # tronco numa forma só: peito, cintura e quadril sem "bolas" separadas
    if r['female']:
        pts = [(44.5, 27.5), (51.5, 27.5), (55.5, 30.8), (55.6, 35), (53.6, 43.5), (56.6, 49.5), (55.5, 52.5), (48, 54),
               (40.5, 52.5), (39.4, 49.5), (42.4, 43.5), (40.4, 35), (40.5, 30.8)]
    else:
        pts = [(44, 27), (52, 27), (57.5, 29.6), (58, 35), (55, 44), (56, 50), (55, 52.6), (48, 54), (41, 52.6), (40, 50),
               (41, 44), (38, 35), (38.5, 29.6)]
    torso = L.mask_poly(pts)
    L.part(); L.cylinder(torso, 'C', bias=-0.15, tilt=0.5, **kw)
    cx, cy, crx, cry = r['chest']
    pec = L.mask_ellipse(cx, cy - 0.5, crx - 1.0, cry - 1.4) & torso
    L.ellipsoid(pec, cx - 1.5, cy - 2, crx + 1, cry + 1, 'C', bias=0.05, **kw)  # mesmo pedaço: sem linha de junção
    if r['female']:
        for bx in (cx - 3.4, cx + 3.4):
            L.part(); ell(L, bx, cy + 1.4, 3.4, 2.8, 'C', bias=0.2, **kw)
    # vinco suave entre as pernas
    for y in range(51, 54):
        L.px(48, y, 'C', 0)
    px, py, prx, pry = r['pelv']
    # trapézio liga pescoço e ombros
    sx, sy = r['sh']
    trap = L.mask_poly([(45, 26.5), (51, 26.5), (96 - sx + 1, sy - 1.5), (96 - sx, sy + 2), (sx, sy + 2), (sx - 1, sy - 1.5)])
    L.part(); L.cylinder(trap, 'C', bias=0.4, tilt=0.3, **kw)
    # braço da esquerda da imagem (o da direita é uma camada própria: muda quando segura a marreta)
    for side in (0,):
        f = (lambda p: p) if side == 0 else mirror
        (a, b, r0, r1) = r['up']; L.part(); L.capsule(f(a), f(b), r0, r1, 'C', bias=-0.2, **kw)
        (a, b, r0, r1) = r['fore']; L.part(); L.capsule(f(a), f(b), r0, r1, 'C', bias=-0.3, **kw)
        dx_, dy_, drx, dry = (*f(r['sh']), *r['delt'])
        L.part(); ell(L, dx_, dy_ + 0.5, drx, dry, 'C', bias=0.3, **kw)
        hx_, hy_, hrx, hry = r['hand']
        hx_ = f((hx_, hy_))[0]
        L.part(); ell(L, hx_, hy_, hrx, hry, 'S', bias=0.0, **kw)
        # punho do traje
        wx, wy = f(r['fore'][1])
        for x in range(int(wx - 2), int(wx + 3)):
            L.px(x, int(wy), 'D', 2)
    # cinto
    belt = L.mask_poly([(30, 46.5), (66, 46.5), (66, 48.2), (30, 48.2)]) & torso
    L.part(); L.cylinder(belt, 'D', bias=0.2, **kw)
    L.px(47, 47, 'O', 4); L.px(48, 47, 'O', 3)
    # gola alta e luz do colarinho
    L.part(); ell(L, 48, 28.2, 5.6 if not r['female'] else 4.8, 2.9, 'C', bias=0.7, **kw)
    L.px(47, 29, 'T', 4); L.px(48, 29, 'T', 4); L.px(49, 29, 'T', 3)
    L.seams()
    # costuras de brasa: descem pelo peito acompanhando o volume e contornam a cintura
    for side in (-1, 1):
        # painel do peito: desce da gola até o cinto, abrindo um pouco
        top_x, bot_x = 48 + side * 3.2, 48 + side * (5.6 if r['female'] else 6.4)
        for y in range(31, 47):
            t = (y - 31) / 15
            xx = int(round(top_x + (bot_x - top_x) * t))
            if L.mat[y, xx] == 'C':
                L.px(xx, y, 'O', 3 if y % 4 else 2)
        if side > 0:
            continue
        # costura do braço
        (a, b, _, _) = r['up']
        a = a if side < 0 else mirror(a)
        bb = r['fore'][1] if side < 0 else mirror(r['fore'][1])
        for t in np.linspace(0.12, 0.92, 14):
            xx = int(round(a[0] + (bb[0] - a[0]) * t + side * -1.2))
            yy = int(round(a[1] + (bb[1] - a[1]) * t))
            if L.mat[yy, xx] == 'C':
                L.px(xx, yy, 'O', 2)
        # dobra do cotovelo e do joelho
        ex, ey = r['up'][1] if side < 0 else mirror(r['up'][1])
        L.px(int(ex) + (1 if side < 0 else -1), int(ey), 'C', 0)
    # pescoço (pele) por cima da gola
    (a, b, r0, r1) = r['neck']
    neck = Part()
    neck.capsule(a, (b[0], b[1] - 1), r0, r1, 'S', bias=-1.0, spread=2.2, dither=0.16)
    return L, neck


# ── cabeça e rosto ──────────────────────────────────────────────────────────

def head(r):
    L = Part()
    hx, hy, rx, ry = r['head']
    cw, cy = r['chin']
    skull = L.mask_ellipse(hx, hy - 0.5, rx, ry - 0.3)
    jaw = L.mask_poly([(hx - rx + 0.2, hy + 1), (hx + rx - 0.2, hy + 1), (hx + rx - 1.4, hy + 5.5), (hx + cw, cy),
                       (hx - cw, cy), (hx - rx + 1.4, hy + 5.5)])
    face = skull | jaw
    for ex in (hx - rx + 0.2, hx + rx - 0.2):
        L.part(); ell(L, ex, hy + 1.5, 1.5, 2.6, 'S', bias=-0.5, spread=2.4, dither=0.16)
    L.part(); L.ellipsoid(face, hx - 0.6, hy - 0.5, rx + 0.6, ry + 1.2, 'S', bias=0.15, spread=2.5, dither=0.18)
    # maçã do rosto e sombra sob o queixo
    for x in range(int(hx - cw), int(hx + cw) + 1):
        L.px(x, int(cy) - 1, 'S', max(0, L.lvl[int(cy) - 1, x] - 1))
    L.seams()
    return L


def face(r, blink=False):
    L = Layer(N, N)
    hx = 48
    y = r['eye_y']
    fem = r['female']
    eyes = ((43, 44, 45, 46), (50, 51, 52, 53))
    for k, xs in enumerate(eyes):
        if blink:
            for x in xs:
                L.px(x, y, 'K', 1)
            L.px(xs[0] - (1 if k == 0 else -4), y, 'K', 1) if fem else None
            continue
        for x in xs:
            L.px(x, y - 1, 'K', 0)
        if fem:
            L.px(xs[0] - 1 if k == 0 else xs[-1] + 1, y - 2, 'K', 0)
            L.px(xs[0] - 1 if k == 0 else xs[-1] + 1, y - 1, 'K', 1)
        L.px(xs[0], y, 'W', 3)
        L.px(xs[3], y, 'W', 2)
        hi, pu = (xs[1], xs[2])
        L.px(hi, y, 'I', 4)
        L.px(pu, y, 'K', 0)
        L.px(hi, y + 1, 'I', 2)
        L.px(pu, y + 1, 'I', 1)
        L.px(xs[0], y + 1, 'S', 2)
        L.px(xs[3], y + 1, 'S', 2)
    # sobrancelhas
    if fem:
        for (x, yy) in ((42, y - 3), (43, y - 4), (44, y - 4), (45, y - 4), (46, y - 3)):
            L.px(x, yy, 'H', 1)
            L.px(96 - x, yy, 'H', 1)
    else:
        for x in (42, 43, 44, 45, 46):
            L.px(x, y - 3, 'H', 1)
            L.px(96 - x, y - 3, 'H', 1)
        for x in (43, 44, 45):
            L.px(x, y - 4, 'H', 0)
            L.px(96 - x, y - 4, 'H', 0)
    # nariz
    L.px(48, y + 1, 'S', 4)
    L.px(48, y + 2, 'S', 3)
    L.px(47, y + 3, 'S', 1)
    L.px(48, y + 4, 'S', 1)
    L.px(49, y + 4, 'S', 0)
    L.px(47, y + 4, 'S', 2)
    # boca
    my = y + 6 + (0 if not fem else 0)
    if fem:
        for x in (46, 47, 48, 49, 50):
            L.px(x, my, 'L', 0 if x in (46, 50) else 1)
        for x in (47, 48, 49):
            L.px(x, my + 1, 'L', 3)
    else:
        L.px(46, my, 'S', 2)
        for x in (47, 48, 49):
            L.px(x, my, 'S', 0)
        L.px(50, my, 'S', 2)
        for x in (47, 48, 49):
            L.px(x, my + 1, 'S', 3)
    return L


# ── cabelos ─────────────────────────────────────────────────────────────────

def hair(style, r):
    front, back = Part(), Part()
    hx, hy, rx, ry = r['head']
    kw = dict(dither=0.16)
    if style == 'curto':
        cap = front.mask_ellipse(hx, hy - 2.6, rx + 1.4, ry - 1.0)
        cap[int(hy - 2):, :] = False
        sides = front.mask_poly([(hx - rx - 0.8, hy - 4), (hx - rx + 2.2, hy - 5), (hx - rx + 1.6, hy + 2.5), (hx - rx + 0.2, hy + 2)]) | \
            front.mask_poly([(hx + rx + 0.8, hy - 4), (hx + rx - 2.2, hy - 5), (hx + rx - 1.6, hy + 2.5), (hx + rx - 0.2, hy + 2)])
        fringe = front.mask_poly([(hx - 6, hy - 4), (hx + 6, hy - 4), (hx + 4.5, hy - 1.5), (hx + 2, hy - 3), (hx, hy - 1),
                                  (hx - 2.5, hy - 2.6), (hx - 5, hy - 1)])
        m = cap | sides | fringe
        front.ellipsoid(m, hx - 1.5, hy - 5, rx + 2, ry - 0.5, 'H', bias=0.25, spread=2.7, **kw)
        for t in np.linspace(0, 1, 7):  # mechas
            x = int(hx - 5 + t * 10)
            front.px(x, int(hy - 8 + abs(t - 0.4) * 3), 'H', 4)
            front.px(x + 1, int(hy - 7 + abs(t - 0.4) * 3), 'H', 3)
        for x in (hx - 4, hx - 1, hx + 3):
            front.px(int(x), int(hy - 3), 'H', 1)
    elif style == 'longo':
        cap = front.mask_ellipse(hx, hy - 2.4, rx + 1.6, ry - 0.6)
        cap[int(hy - 2.5):, :] = False
        left = front.mask_poly([(hx - rx - 1.6, hy - 4), (hx - rx + 2.6, hy - 4), (hx - rx + 2.0, hy + 8), (hx - rx + 2.6, hy + 19),
                                (hx - rx - 1.4, hy + 20), (hx - rx - 2.4, hy + 9)])
        right = front.mask_poly([(96 - p[0], p[1]) for p in [(hx - rx - 1.6, hy - 4), (hx - rx + 2.6, hy - 4), (hx - rx + 2.0, hy + 8),
                                                             (hx - rx + 2.6, hy + 19), (hx - rx - 1.4, hy + 20), (hx - rx - 2.4, hy + 9)]])
        swoop = front.mask_poly([(hx - 7, hy - 5), (hx + 1, hy - 6), (hx - 1, hy - 3), (hx - 5, hy - 1.5)])
        m = cap | left | right | swoop
        front.ellipsoid(m, hx - 1.5, hy - 2, rx + 3, ry + 12, 'H', bias=0.2, spread=2.7, **kw)
        for x in range(int(hx + 1), int(hx + 2)):
            for y in range(int(hy - 10), int(hy - 4)):
                front.px(x, y, 'H', 1)
        for (x, y) in [(hx - 4, hy - 8), (hx - 3, hy - 9), (hx + 4, hy - 8), (hx - rx - 1, hy + 4), (hx - rx - 1, hy + 10),
                       (hx + rx + 1, hy + 6), (hx + rx + 1, hy + 12)]:
            front.px(int(x), int(y), 'H', 4)
        bk = back.mask_poly([(hx - rx - 2.5, hy - 6), (hx + rx + 2.5, hy - 6), (hx + rx + 3.4, hy + 14), (hx + rx + 2.2, hy + 22),
                             (hx - rx - 2.2, hy + 22), (hx - rx - 3.4, hy + 14)])
        back.cylinder(bk, 'H', bias=-1.0, spread=2.0, **kw)
        for x in range(int(hx - rx - 1), int(hx + rx + 2), 3):
            for y in range(int(hy + 12), int(hy + 22)):
                if bk[y, x]:
                    back.px(x, y, 'H', 0)
    elif style == 'cacheado':
        rng = np.random.default_rng(11)
        bk = back.mask_ellipse(hx, hy - 3, rx + 6.5, ry + 3.6)
        back.ellipsoid(bk, hx - 2, hy - 6, rx + 7, ry + 4, 'H', bias=-0.55, spread=2.4, **kw)
        top = front.mask_ellipse(hx, hy - 5.5, rx + 4.6, ry - 1.6)
        top[int(hy - 3):, :] = False
        front.ellipsoid(top, hx - 2, hy - 8, rx + 4.6, ry - 1, 'H', bias=0.15, spread=2.6, **kw)
        for layer, msk, n in ((back, bk, 160), (front, top, 90)):
            for _ in range(n):  # cachos: pequenos arcos com brilho e sombra
                y, x = rng.integers(0, N, 2)
                if msk[y, x] and x + 1 < N and msk[y, x + 1] and y + 1 < N:
                    lv = layer.lvl[y, x]
                    layer.px(x, y, 'H', min(4, lv + 1))
                    layer.px(x + 1, y, 'H', min(4, lv + 1))
                    if msk[y + 1, x]:
                        layer.px(x, y + 1, 'H', max(0, lv - 2))
    return front, back


# ── equipamentos ────────────────────────────────────────────────────────────

def armor(r):
    L = Part()
    kw = dict(spread=2.9, dither=0.16)
    cx, cy, crx, cry = r['chest']
    fem = r['female']
    if fem:
        # couraça moldada: decote, dois volumes sobre o peito, cintura fina
        plate = L.mask_poly([(cx - 4.6, cy - cry + 1.2), (cx - 1.2, cy - cry + 3.2), (cx + 1.2, cy - cry + 3.2), (cx + 4.6, cy - cry + 1.2),
                             (cx + crx - 0.6, cy - 2.5), (cx + crx - 0.4, cy + 2.5), (cx + 5.6, cy + cry + 1), (cx, cy + cry + 3),
                             (cx - 5.6, cy + cry + 1), (cx - crx + 0.4, cy + 2.5), (cx - crx + 0.6, cy - 2.5)])
        L.part(); L.cylinder(plate, 'M', bias=-0.3, tilt=0.4, spread=2.6, dither=0.06)
        for bx in (cx - 3.5, cx + 3.5):
            m = L.mask_ellipse(bx, cy + 1.2, 3.7, 3.2) & plate
            L.part(); L.ellipsoid(m, bx - 1.2, cy - 0.4, 4.2, 3.6, 'M', bias=0.3, spread=2.6, dither=0.0)
            L.px(int(bx - 1.5), int(cy), 'M', 4)
        for y in range(int(cy - cry + 4), int(cy + cry + 2)):
            L.px(48, y, 'M', 1 if y < cy + 3 else 3)
        ab = L.mask_poly([(cx - 5, cy + cry + 1), (cx + 5, cy + cry + 1), (cx + 4.2, cy + cry + 6), (cx - 4.2, cy + cry + 6)])
    else:
        plate = L.mask_poly([(cx - crx + 2.5, cy - cry + 1.5), (cx + crx - 2.5, cy - cry + 1.5), (cx + crx + 0.3, cy - 1), (cx + crx - 1, cy + cry - 0.5),
                             (cx, cy + cry + 3.5), (cx - crx + 1, cy + cry - 0.5), (cx - crx - 0.3, cy - 1)])
        L.part(); L.ellipsoid(plate, cx - 2, cy - 3, crx + 2, cry + 4, 'M', bias=-0.1, **kw)
        ab = L.mask_poly([(cx - 6, cy + cry + 1), (cx + 6, cy + cry + 1), (cx + 5, cy + cry + 6.5), (cx - 5, cy + cry + 6.5)])
    L.part(); L.cylinder(ab, 'M', bias=-0.4, **kw)
    for y in (int(cy + cry + 3), int(cy + cry + 5)):
        for x in range(int(cx - 5), int(cx + 6)):
            if ab[y, x]:
                L.px(x, y, 'M', 1)
    if fem:  # brasa acompanhando o decote
        for side in (-1, 1):
            for k in range(3):
                L.px(int(48 + side * (2 + k)), int(cy - cry + 3 - k * 0.6), 'O', 3)
        L.px(48, int(cy + cry + 1), 'O', 4)
    else:
        for side in (-1, 1):
            for k in range(4):
                L.px(int(cx + side * (3 + k)), int(cy - 1 + k * 0.5), 'O', 3 if k < 3 else 2)
        L.px(48, int(cy + 3), 'O', 4); L.px(47, int(cy + 3), 'O', 3); L.px(49, int(cy + 3), 'O', 3)
        L.px(48, int(cy + 2), 'O', 3); L.px(48, int(cy + 4), 'O', 3)
    for side in (0, 1):
        sx, sy = r['sh'] if side == 0 else mirror(r['sh'])
        rx_, ry_ = r['delt'][0] + 0.7, r['delt'][1] + 0.4
        sx = sx + (0.6 if side == 0 else -0.6)
        for k in range(2):  # ombreira discreta em duas lâminas, rente ao ombro
            m = L.mask_ellipse(sx, sy - 0.5 + k * 2.2, rx_ - k * 0.7, ry_ - k * 0.9)
            m[int(sy + 1.5 + k * 2.2):, :] = False
            L.part(); L.ellipsoid(m, sx - 1.2, sy - 2 + k * 2.2, rx_, ry_, 'M', bias=-0.15 - k * 0.25, **kw)
    L.seams()
    return L


def helmet(r):
    L = Part()
    hx, hy, rx, ry = r['head']
    kw = dict(spread=2.9, dither=0.16)
    dome = L.mask_ellipse(hx, hy - 1.5, rx + 2.0, ry + 0.6)
    dome[int(hy - 1):, :] = False
    L.part(); L.ellipsoid(dome, hx - 2, hy - 4, rx + 2.4, ry + 1, 'M', bias=0.0, **kw)
    crest = L.mask_poly([(hx - 1.2, hy - ry - 2.2), (hx + 1.2, hy - ry - 2.2), (hx + 1.4, hy - 2), (hx - 1.4, hy - 2)])
    L.part(); L.cylinder(crest, 'D', bias=0.3, **kw)
    band = L.mask_poly([(hx - rx - 2.2, hy - 3.2), (hx + rx + 2.2, hy - 3.2), (hx + rx + 2.2, hy - 0.4), (hx - rx - 2.2, hy - 0.4)])
    L.part(); L.cylinder(band, 'D', bias=0.4, **kw)
    for x in range(int(hx - rx), int(hx + rx + 1)):
        L.px(x, int(hy - 2), 'O', 4 if abs(x - hx) < 3 else 3)
    cheeks = L.mask_poly([(hx - rx - 2.2, hy - 0.5), (hx - rx + 1.5, hy - 0.5), (hx - rx + 1.5, hy + 5.5), (hx - rx - 1, hy + 4.5)]) | \
        L.mask_poly([(hx + rx + 2.2, hy - 0.5), (hx + rx - 1.5, hy - 0.5), (hx + rx - 1.5, hy + 5.5), (hx + rx + 1, hy + 4.5)])
    L.part(); L.cylinder(cheeks, 'M', bias=-0.3, **kw)
    L.seams()
    return L


def hammer(r):
    """Marreta descansando: cabeça no chão (faces largas nas pontas, meio mais fino, colar de metal),
    cabo com empunhadura subindo até a mão e a ponta aparecendo acima dela."""
    L = Part()
    kw = dict(spread=2.8, dither=0.16)
    hx_, hy_ = mirror((r['hand'][0], r['hand'][1]))
    bx, by = hx_ + 5.5, 85.0
    top = (hx_ - 0.2, hy_ - 7.5)
    L.part(); L.capsule(top, (bx - 0.2, by - 4.5), 1.9, 1.9, 'R', bias=-0.1, **kw)
    for t in np.linspace(0.08, 0.32, 4):  # tiras da empunhadura
        x = int(round(top[0] + (bx - 0.2 - top[0]) * t)); y = int(round(top[1] + (by - 4.5 - top[1]) * t))
        for dx in (-1, 0, 1):
            L.px(x + dx, y, 'D', 2 if dx < 1 else 1)
    pm = L.mask_ellipse(top[0], top[1] - 0.5, 2.4, 1.6)
    L.part(); L.ellipsoid(pm, top[0] - 0.6, top[1] - 1, 2.4, 1.6, 'M', bias=0.2, **kw)
    # cabeça: faces largas nas pontas, miolo mais fino
    mid = L.mask_poly([(bx - 5, by - 3.6), (bx + 5, by - 3.6), (bx + 5, by + 3.6), (bx - 5, by + 3.6)])
    L.part(); L.cylinder(mid, 'D', bias=-0.1, axis='h', **kw)
    for side in (-1, 1):
        x0, x1 = (bx - 10, bx - 5) if side < 0 else (bx + 5, bx + 10)
        face_m = L.mask_poly([(x0, by - 5.6), (x1, by - 5.6), (x1 + (0.8 if side > 0 else 0), by - 4.6), (x1 + (0.8 if side > 0 else 0), by + 4.6),
                              (x1, by + 5.6), (x0, by + 5.6), (x0 - (0.8 if side < 0 else 0), by + 4.6), (x0 - (0.8 if side < 0 else 0), by - 4.6)])
        L.part(); L.cylinder(face_m, 'M', bias=-0.05, axis='h', **kw)
        fx = int(x0) if side < 0 else int(x1)
        for y in range(int(by - 4), int(by + 5)):
            L.px(fx, y, 'M', 4 if side < 0 else 1)
        # anel de brasa entre a face e o miolo
        rx_ = int(bx - 5) if side < 0 else int(bx + 4)
        for y in range(int(by - 3), int(by + 4)):
            L.px(rx_, y, 'O', 3 if y % 2 else 2)
    collar = L.mask_poly([(bx - 2.6, by - 6), (bx + 2.2, by - 6), (bx + 2.2, by - 3.4), (bx - 2.6, by - 3.4)])
    L.part(); L.cylinder(collar, 'M', bias=0.1, **kw)
    core = L.mask_ellipse(bx, by + 0.4, 2.0, 2.0)
    L.part(); L.ellipsoid(core, bx - 0.5, by - 0.2, 2.0, 2.0, 'O', bias=0.9, spread=1.6, dither=0.1)
    L.seams()
    return L


# ── braço direito (da imagem): solto ao lado do corpo ou dobrado segurando a marreta no ombro ──

def grip(r):
    """Geometria da pose da marreta no ombro: mão, cotovelo, direção do cabo."""
    sx, sy = mirror(r['sh'])
    fem = r['female']
    elbow = (sx + (1.6 if fem else 2.0), 43.5)
    hand = (sx - (3.6 if fem else 4.2), 38.0 if fem else 37.0)
    s_top = (sx + 0.6, sy - 3.4)
    d = np.array(s_top) - np.array(hand)
    d = d / np.linalg.norm(d)
    return elbow, hand, s_top, d


def right_arm(r, holding):
    L = Part()
    kw = dict(spread=2.8, dither=0.16)
    sx, sy = mirror(r['sh'])
    a_up, b_up, r0u, r1u = r['up']
    if not holding:
        (a, b, r0, r1) = r['up']; L.part(); L.capsule(mirror(a), mirror(b), r0, r1, 'C', bias=-0.2, **kw)
        (a, b, r0, r1) = r['fore']; L.part(); L.capsule(mirror(a), mirror(b), r0, r1, 'C', bias=-0.3, **kw)
        L.part(); ell(L, sx, sy + 0.5, *r['delt'], 'C', bias=0.3, **kw)
        hx_, hy_, hrx, hry = r['hand']
        L.part(); ell(L, 96 - hx_, hy_, hrx, hry, 'S', bias=0.0, **kw)
        wx, wy = mirror(r['fore'][1])
        for x in range(int(wx - 2), int(wx + 3)):
            L.px(x, int(wy), 'D', 2)
        a, bb = mirror(r['up'][0]), mirror(r['fore'][1])
        for t in np.linspace(0.12, 0.92, 14):
            xx = int(round(a[0] + (bb[0] - a[0]) * t + 1.2)); yy = int(round(a[1] + (bb[1] - a[1]) * t))
            if L.mat[yy, xx] == 'C':
                L.px(xx, yy, 'O', 2)
        L.seams()
        return L, None
    elbow, hand, _, _ = grip(r)
    L.part(); L.capsule(mirror(a_up), elbow, r0u, r1u, 'C', bias=-0.2, **kw)
    L.part(); ell(L, sx, sy + 0.5, *r['delt'], 'C', bias=0.3, **kw)
    r0f, r1f = r['fore'][2], r['fore'][3]
    F = Part()  # antebraço: por cima da armadura, para aparecer na frente do peito
    F.part(); F.capsule(elbow, hand, r0f + 0.2, r1f + 0.3, 'C', bias=0.1, **kw)
    for t in np.linspace(0.2, 0.85, 6):
        q = np.array(elbow) + (np.array(hand) - np.array(elbow)) * t
        F.px(int(round(q[0])), int(round(q[1] - r0f + 0.5)), 'O', 2)
    wx, wy = np.array(hand) + (np.array(elbow) - np.array(hand)) * 0.22
    for k in (-1, 0, 1):
        F.px(int(round(wx)) + k, int(round(wy)) - k, 'D', 2)
    F.seams()
    for t in np.linspace(0.15, 0.9, 10):  # costura do braço dobrado
        xx = int(round(mirror(a_up)[0] + (elbow[0] - mirror(a_up)[0]) * t + 1.2)); yy = int(round(mirror(a_up)[1] + (elbow[1] - mirror(a_up)[1]) * t))
        if L.mat[yy, xx] == 'C':
            L.px(xx, yy, 'O', 2)
    L.seams()
    # a mão fica numa camada à parte, por cima do cabo
    M = Part()
    hrx, hry = r['hand'][2], r['hand'][3]
    M.part(); ell(M, hand[0], hand[1], hrx + 0.3, hry - 0.4, 'S', bias=0.1, spread=2.6, dither=0.12)
    for k in (-1, 0, 1):  # dedos fechados no cabo
        M.px(int(hand[0]) + k, int(hand[1] + hry - 1.2), 'S', 1)
    return L, (F, M)


def hammer_shoulder(r):
    """Marreta no ombro: atrás, a cabeça e o fim do cabo; na frente, o trecho do cabo da mão até o ombro."""
    kw = dict(spread=2.8, dither=0.14)
    _, hand, s_top, d = grip(r)
    p = np.array([d[1], -d[0]])                     # perpendicular ao cabo
    if p[0] < 0:
        p = -p
    pommel = np.array(hand) - d * 6.0
    end = np.array(s_top) + d * 11.0
    back, front = Part(), Part()
    # trecho de trás: do ombro até a cabeça
    back.part(); back.capsule(tuple(np.array(s_top) - d * 1.0), tuple(end), 1.9, 1.9, 'R', bias=-0.2, **kw)
    mid0, mid1 = end - p * 4.6, end + p * 4.6
    back.part(); back.capsule(tuple(mid0), tuple(mid1), 3.4, 3.4, 'D', bias=-0.1, **kw)
    for side in (-1, 1):
        a = end + p * side * 4.4
        b = end + p * side * 8.0
        back.part(); back.capsule(tuple(a), tuple(b), 4.8, 4.8, 'D', bias=0.25, **kw)
        tip = end + p * side * 12.4  # face de golpe: borda de aço
        for t in np.linspace(-3.6, 3.6, 9):
            q = end + p * side * 12.0 + d * t
            back.px(int(round(q[0])), int(round(q[1])), 'M', 3 if side < 0 else 2)
        ring = end + p * side * 4.3
        for t in np.linspace(-3, 3, 7):
            q = ring + d * t
            back.px(int(round(q[0])), int(round(q[1])), 'O', 3 if int(t) % 2 else 2)
    core = back.mask_ellipse(end[0], end[1], 2.1, 2.1)
    back.part(); back.ellipsoid(core, end[0] - 0.5, end[1] - 0.5, 2.1, 2.1, 'O', bias=0.9, spread=1.6, dither=0.1)
    back.seams()
    # trecho da frente: da ponta (abaixo da mão) até o ombro, por cima do peito
    front.part(); front.capsule(tuple(pommel), tuple(s_top), 1.9, 1.9, 'R', bias=0.0, **kw)
    for t in (0.55, 0.68, 0.81):  # tiras da empunhadura acima da mão
        q = pommel + (np.array(s_top) - pommel) * t
        front.px(int(round(q[0])), int(round(q[1])), 'D', 1)
        front.px(int(round(q[0])) + 1, int(round(q[1])), 'D', 2)
    pm = front.mask_ellipse(pommel[0], pommel[1], 2.3, 2.3)
    front.part(); front.ellipsoid(pm, pommel[0] - 0.6, pommel[1] - 0.6, 2.3, 2.3, 'M', bias=0.2, **kw)
    front.seams()
    return back, front



def build():
    layers = {}
    for g, r in RIG.items():
        b, neck = body(r)
        layers[f'corpo_{g}'] = dict(px=b.encode(), part='body')
        layers[f'pescoco_{g}'] = dict(px=neck.encode(), part='body')
        layers[f'cabeca_{g}'] = dict(px=head(r).encode(), part='head')
        layers[f'rosto_{g}'] = dict(px=face(r).encode(), part='head')
        layers[f'rosto_{g}_piscar'] = dict(px=face(r, True).encode(), part='head')
        layers[f'armadura_{g}'] = dict(px=armor(r).encode(), part='body')
        layers[f'elmo_{g}'] = dict(px=helmet(r).encode(), part='head')
        arm, _ = right_arm(r, False)
        arm_h, (fore_h, hand_h) = right_arm(r, True)
        mb, mf = hammer_shoulder(r)
        layers[f'braco_{g}'] = dict(px=arm.encode(), part='body')
        layers[f'braco_martelo_{g}'] = dict(px=arm_h.encode(), part='body')
        layers[f'mao_martelo_{g}'] = dict(px=hand_h.encode(), part='body')
        layers[f'antebraco_martelo_{g}'] = dict(px=fore_h.encode(), part='body')
        layers[f'martelo_tras_{g}'] = dict(px=mb.encode(), part='body')
        layers[f'martelo_frente_{g}'] = dict(px=mf.encode(), part='body')
        for s in ('curto', 'longo', 'cacheado'):
            fr, bk = hair(s, r)
            layers[f'cabelo_{s}_{g}'] = dict(px=fr.encode(), part='head')
            layers[f'cabelo_{s}_tras_{g}'] = dict(px=bk.encode(), part='head')
    return layers


if __name__ == '__main__':
    out = build()
    json.dump(out, open(sys.argv[1], 'w'))
    print(len(out), 'camadas')
