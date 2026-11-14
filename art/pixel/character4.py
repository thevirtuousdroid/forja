"""Forja · direção cyberpunk (conceito): implantes, neon, techwear, sobretudo, katana, visor.

Acrescenta ao personagem aprovado (character3) os detalhes cyber do corpo e reinterpreta itens.
Gera layers4.json (todas as camadas de character3 + as novas, que substituem as antigas de mesmo nome).
"""
import json, sys
import numpy as np
from character2 import N, Part, RIG, mirror, ell, grip
import character3 as c3

KW = dict(spread=2.8, dither=0.16)


# ── detalhes cyber do corpo (sempre presentes) ──────────────────────────────

def cyber_body(r):
    """Alças táticas, bolso na coxa, computador de pulso e sola de LED."""
    L = Part()
    fem = r['female']
    # alça diagonal do peito
    a, b = ((40.5, 30.5), (55, 46)) if not fem else ((42, 31), (53.5, 45.5))
    strap = L.mask_line([a, b], 2)
    L.part(); L.cylinder(strap, 'D', bias=0.1, **KW)
    L.part(); ell(L, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 1.6, 1.6, 'M', bias=0.4, **KW)
    # bolso na coxa esquerda (da imagem)
    tx = r['thigh'][0][0] - (1.5 if fem else 1.0)
    pocket = L.mask_poly([(tx - 3.6, 58), (tx + 1.2, 58), (tx + 1.0, 64.5), (tx - 3.4, 64.5)])
    L.part(); L.cylinder(pocket, 'D', bias=0.1, **KW)
    for x in range(int(tx - 3), int(tx + 1)):
        L.px(x, 58, 'M', 2)
    L.px(int(tx - 1), 61, 'T', 3)
    # computador de pulso no antebraço esquerdo
    (fa, fb, _, _) = r['fore']
    cx_, cy_ = fa[0] + (fb[0] - fa[0]) * 0.62, fa[1] + (fb[1] - fa[1]) * 0.62
    pad = L.mask_poly([(cx_ - 2.6, cy_ - 2.2), (cx_ + 2.6, cy_ - 2.2), (cx_ + 2.6, cy_ + 2.2), (cx_ - 2.6, cy_ + 2.2)])
    L.part(); L.cylinder(pad, 'D', bias=0.2, **KW)
    for y in range(int(cy_ - 1), int(cy_ + 2)):
        for x in range(int(cx_ - 1.5), int(cx_ + 2)):
            L.px(x, y, 'T', 4 if (x + y) % 3 == 0 else 3)
    # sola de LED nas botas
    for side in (0, 1):
        fx = r['foot'][0] if side == 0 else 96 - r['foot'][0]
        for x in range(int(fx - r['foot'][2] + 1), int(fx + r['foot'][2])):
            L.px(x, 91, 'P', 3 if x % 3 else 4)
    L.seams()
    return L


def implants(r):
    """Implantes no rosto: linha na têmpora e na maçã do rosto, módulo na orelha, porta no pescoço."""
    L = Layer = Part()
    hx, hy, rx, ry = r['head']
    y = r['eye_y']
    for k, (x, yy) in enumerate([(hx - rx + 1, hy - 3), (hx - rx + 1, hy - 2), (hx - rx + 1.4, hy - 1), (hx - rx + 2, hy)]):
        L.px(int(x), int(yy), 'T', 4 if k == 0 else 3)
    for x in (43, 44):
        L.px(x, y + 3, 'T', 3)
    L.px(42, y + 3, 'T', 4)
    ex = hx + rx - 0.2
    mod = L.mask_ellipse(ex + 0.4, hy + 1.2, 1.6, 2.4)
    L.part(); L.ellipsoid(mod, ex, hy + 0.6, 1.6, 2.4, 'D', bias=0.3, **KW)
    L.px(int(ex + 0.4), int(hy + 0.5), 'P', 4)
    L.px(int(ex + 0.4), int(hy + 2), 'P', 3)
    return L


# ── cabeça ──────────────────────────────────────────────────────────────────

def visor_helmet(r):
    """Capacete tático com visor de HUD (reinterpreta o Elmo de ferro)."""
    L = Part()
    hx, hy, rx, ry = r['head']
    y = r['eye_y']
    dome = L.mask_ellipse(hx, hy - 1.2, rx + 1.8, ry + 0.6)
    dome[int(y + 1.5):, :] = False
    L.part(); L.ellipsoid(dome, hx - 2.4, hy - 4.6, rx + 2.4, ry + 1.2, 'D', bias=0.15, spread=3.0, dither=0.1)
    for (x, yy) in [(hx - 4, hy - ry + 0.5), (hx - 3, hy - ry + 0.2), (hx - 5, hy - ry + 1.4)]:
        L.px(int(x), int(yy), 'M', 4)  # brilho cromado
    visor = L.mask_poly([(hx - rx - 1.6, y - 2.2), (hx + rx + 1.6, y - 2.2), (hx + rx + 1.2, y + 1.6), (hx - rx - 1.2, y + 1.6)])
    L.part(); L.flat(visor, 'T', 2)
    for xx in range(int(hx - rx - 1), int(hx + rx + 2)):
        L.px(xx, int(y - 2), 'T', 3)
        L.px(xx, int(y), 'T', 4 if xx % 4 == 0 else 3)  # linha de leitura
    for xx in range(int(hx - rx + 1), int(hx - rx + 4)):
        L.px(xx, int(y - 1), 'P', 4)  # marcação do HUD
    for side in (-1, 1):
        ear = L.mask_ellipse(hx + side * (rx + 1.2), hy + 1.6, 2.2, 3.0)
        L.part(); L.ellipsoid(ear, hx + side * (rx + 1.2) - 0.6, hy + 1, 2.2, 3, 'D', bias=0.2, **KW)
        L.px(int(hx + side * (rx + 1.2)), int(hy + 2), 'P', 4)
    L.seams()
    return L


def respirator_hood(r):
    """Capuz techwear com máscara respiradora (reinterpreta o Capuz do viajante)."""
    front, _ = c3.hood(r)
    hx, hy, rx, ry = r['head']
    y = r['eye_y']
    cw, cy = r['chin']
    mask = front.mask_poly([(hx - rx + 0.6, y + 2.2), (hx + rx - 0.6, y + 2.2), (hx + rx - 1.0, y + 5.5), (hx + cw + 0.4, cy + 0.6),
                            (hx - cw - 0.4, cy + 0.6), (hx - rx + 1.0, y + 5.5)])
    front.part(); front.cylinder(mask, 'D', bias=0.3, spread=2.8, dither=0.1)
    for side in (-1, 1):
        f = front.mask_ellipse(hx + side * 3.6, y + 6.2, 1.9, 1.9)
        front.part(); front.ellipsoid(f, hx + side * 3.6 - 0.5, y + 5.6, 1.9, 1.9, 'M', bias=0.2, **KW)
        front.px(int(hx + side * 3.6), int(y + 6), 'D', 0)
    for x in range(int(hx - 1), int(hx + 2)):
        front.px(x, int(y + 4), 'P', 4 if x == int(hx) else 3)
    front.seams()
    return front


def holo_halo(r):
    """Auréola holográfica flutuando (reinterpreta a Coroa de brasa)."""
    L = Part()
    hx, hy, rx, ry = r['head']
    cy_ = hy - ry - 2.6
    ring = L.mask_ellipse(hx, cy_, rx + 2.6, 2.0) & ~L.mask_ellipse(hx, cy_, rx + 1.2, 0.9)
    for (yy, xx) in zip(*np.where(ring)):
        L.px(xx, yy, 'O', 4 if yy < cy_ else 3)
    for dx in (-5, 0, 5):  # pontas de luz
        L.px(int(hx + dx), int(cy_ - 2.2), 'O', 4)
        L.px(int(hx + dx), int(cy_ - 3.2), 'O', 3)
    band = L.mask_poly([(hx - rx - 0.3, hy - 5.6), (hx + rx + 0.3, hy - 5.6), (hx + rx + 0.2, hy - 4.6), (hx - rx - 0.2, hy - 4.6)])
    L.flat(band, 'D', 2)
    for x in range(int(hx - rx + 1), int(hx + rx), 3):
        L.px(x, int(hy - 5), 'O', 3)
    return L


# ── roupas ──────────────────────────────────────────────────────────────────

def leather_jacket(r):
    """Jaqueta de couro preta com gola alta e neon no zíper (reinterpreta o Gibão)."""
    L = Part()
    m = c3.torso_mask(L, r, 0.08)
    m &= ~L.mask_poly([(46, 27), (50, 27), (49.2, 47), (46.8, 47)])  # aberta no meio
    L.part(); L.cylinder(m, 'J', bias=-0.1, spread=3.0, tilt=0.4, dither=0.1)
    for (x, y) in [(41, 34), (42, 33), (40, 36), (54, 34), (55, 33)]:
        L.px(x, y, 'J', 4)  # brilho do couro
    for side in (-1, 1):  # gola alta levantada
        col = L.mask_poly([(48 + side * 2.4, 24.5), (48 + side * 7.4, 25.2), (48 + side * 8.6, 30.5), (48 + side * 4.2, 30)])
        L.part(); L.cylinder(col, 'J', bias=0.2, **KW)
        for y in range(28, 47):  # neon do zíper
            x = int(round(48 + side * (1.6 + (y - 28) * 0.02)))
            if L.mat[y, x]:
                L.px(x, y, 'P', 4 if y % 5 == 0 else 3)
    for side in (0, 1):  # ombreiras da jaqueta
        sx, sy = r['sh'] if side == 0 else mirror(r['sh'])
        sh = L.mask_ellipse(sx, sy - 0.4, r['delt'][0] + 0.8, 2.4)
        sh[int(sy + 1):, :] = False
        L.part(); L.ellipsoid(sh, sx - 1, sy - 1.2, r['delt'][0] + 1, 2.6, 'J', bias=0.3, **KW)
    L.seams()
    return L


def sleeves(r, mat, pose):
    """Mangas na cor da peça, por cima dos braços (pose solta ou segurando a marreta)."""
    left, right_up, right_fore = Part(), Part(), Part()
    (a, b, r0, r1) = r['up']; left.part(); left.capsule(a, b, r0 + 0.5, r1 + 0.5, mat, bias=-0.2, **KW)
    (a, b, r0, r1) = r['fore']; left.part(); left.capsule(a, (b[0], b[1] - 1.5), r0 + 0.5, r1 + 0.6, mat, bias=-0.3, **KW)
    left.seams()
    if pose == 'solto':
        (a, b, r0, r1) = r['up']; right_up.part(); right_up.capsule(mirror(a), mirror(b), r0 + 0.5, r1 + 0.5, mat, bias=-0.2, **KW)
        (a, b, r0, r1) = r['fore']; right_up.part(); right_up.capsule(mirror(a), mirror((b[0], b[1] - 1.5)), r0 + 0.5, r1 + 0.6, mat, bias=-0.3, **KW)
        right_up.seams()
        return left, right_up, None
    elbow, hand, _, _ = grip(r)
    (a, b, r0, r1) = r['up']
    right_up.part(); right_up.capsule(mirror(a), elbow, r0 + 0.5, r1 + 0.5, mat, bias=-0.2, **KW)
    right_up.seams()
    hv = np.array(hand) + (np.array(elbow) - np.array(hand)) * 0.25
    right_fore.part(); right_fore.capsule(elbow, tuple(hv), r['fore'][2] + 0.7, r['fore'][3] + 0.8, mat, bias=0.1, **KW)
    right_fore.seams()
    return left, right_up, right_fore


COATS = {
    'cap_curta': dict(mat='C', lining='T', length=66),
    'cap_constante': dict(mat='V', lining='Y', length=80),
    'cap_fenix': dict(mat='F', lining='O', length=80),
    'cap_mestre': dict(mat='D', lining='O', length=82),
}


def trench(cid, r):
    """Sobretudo longo aberto (reinterpreta as capas): costas, abas da frente, gola larga e forro neon."""
    cfg = COATS[cid]
    back, front = Part(), Part()
    fem = r['female']
    sl, sr = (37, 59) if not fem else (39.5, 56.5)
    hem = cfg['length']
    flare = 6.5 if hem > 70 else 3.5
    bk = back.mask_poly([(sl, 29), (sr, 29), (sr + flare, hem), (sl - flare, hem)])
    back.part(); back.cylinder(bk, cfg['mat'], bias=-0.8, spread=2.2, dither=0.12)
    for x in range(int(sl - flare), int(sr + flare) + 1):  # forro aparecendo na barra
        if bk[hem - 1, x]:
            back.px(x, hem - 1, cfg['lining'], 3)
    back.seams()
    for side in (-1, 1):  # abas da frente
        out_top, out_bot = (sl if side < 0 else sr), (sl - flare if side < 0 else sr + flare)
        in_top, in_bot = 48 + side * 3.6, 48 + side * 5.4
        pts = [(in_top, 29), (out_top, 29.5), (out_bot, hem), (in_bot + side * 0.6, hem), (in_bot, 52), (in_top + side * 0.8, 40)]
        panel = front.mask_poly(pts)
        front.part(); front.cylinder(panel, cfg['mat'], bias=-0.15, spread=2.8, tilt=0.2, dither=0.12)
        for y in range(30, hem):  # forro neon na borda interna
            t = (y - 29) / (hem - 29)
            x = int(round(in_top + side * 0.8 * min(1, t * 2.5) + (in_bot - in_top) * t))
            if front.mat[y, x]:
                front.px(x, y, cfg['lining'], 3 if y % 6 else 4)
        lap = front.mask_poly([(48 + side * 2.4, 25), (48 + side * 8.8, 25.6), (48 + side * 9.6, 31), (48 + side * 4.4, 36)])
        front.part(); front.cylinder(lap, cfg['mat'], bias=0.15, **KW)
        for y in range(52, hem, 7):  # bolso
            pass
    front.seams()
    return back, front


# ── armas ───────────────────────────────────────────────────────────────────

def katana(r):
    """Katana na mão, lâmina para baixo, fio de neon magenta (reinterpreta a Lâmina do Foco)."""
    L = Part()
    hx_, hy_ = mirror((r['hand'][0], r['hand'][1]))
    top = (hx_ - 0.8, hy_ - 5.5)
    guard_c = (hx_ + 0.5, hy_ + 3.0)
    tip = (hx_ + 8.6, 90)
    L.part(); L.capsule(top, (hx_ + 0.3, hy_ + 2), 1.2, 1.2, 'D', bias=0.1, **KW)
    for t in np.linspace(0.1, 0.9, 5):
        x = int(round(top[0] + (hx_ + 0.3 - top[0]) * t)); y = int(round(top[1] + (hy_ + 2 - top[1]) * t))
        L.px(x, y, 'P', 2)
    d = np.array(tip) - np.array(guard_c); d = d / np.linalg.norm(d)
    p = np.array([d[1], -d[0]])
    tsuba = L.mask_ellipse(guard_c[0], guard_c[1], 2.6, 1.6)
    L.part(); L.ellipsoid(tsuba, guard_c[0] - 0.5, guard_c[1] - 0.5, 2.6, 1.6, 'M', bias=0.3, **KW)
    base = np.array(guard_c) + d * 1.4
    curve = lambda t: base + (np.array(tip) - base) * t + p * (1.2 * np.sin(t * np.pi) )
    for t in np.linspace(0, 1, 70):
        q = curve(t)
        w = 1.0 if t < 0.92 else 0.5
        for s in np.linspace(-w, w, 3):
            qq = q + p * s
            L.px(int(round(qq[0])), int(round(qq[1])), 'M', 4 if s < 0 else 2)
        e = q - p * (w + 0.6)
        L.px(int(round(e[0])), int(round(e[1])), 'P', 4 if int(t * 70) % 4 else 3)
    L.seams()
    return L, None


def thermal_hammer(r, scale=0.92):
    """Marreta térmica: cabeça com pistões e núcleo de calor (reinterpreta o Martelo de aprendiz)."""
    back, front = c3.big_hammer(r, scale=scale, gold=False)
    _, hand, s_top, d = grip(r)
    p = np.array([d[1], -d[0]]); p = -p if p[0] < 0 else p
    end = np.array(s_top) + d * (11.0 + (scale - 1) * 4)
    for side in (-1, 1):  # pistões
        for t in np.linspace(5.0 * scale, 7.4 * scale, 3):
            q = end + p * side * t - d * (3.6 * scale)
            back.px(int(round(q[0])), int(round(q[1])), 'M', 4)
            q2 = end + p * side * t + d * (3.6 * scale)
            back.px(int(round(q2[0])), int(round(q2[1])), 'T', 3)
    return back, front


# ── montagem ────────────────────────────────────────────────────────────────

def build():
    layers = json.load(open('layers3.json'))
    def put(name, L, part):
        if L is not None and (L.mat != '').any():
            layers[name] = dict(px=L.encode(), part=part)
    for g, r in RIG.items():
        put(f'cyber_{g}', cyber_body(r), 'body')
        put(f'implante_{g}', implants(r), 'head')
        put(f'cab_elmo_ferro_{g}', visor_helmet(r), 'head')
        put(f'cab_capuz_{g}', respirator_hood(r), 'head')
        put(f'cab_coroa_{g}', holo_halo(r), 'head')
        put(f'cor_gibao_{g}', leather_jacket(r), 'body')
        for mat in ('J', 'C', 'V', 'F', 'D'):
            for pose in ('solto', 'ombro'):
                lft, rup, rfo = sleeves(r, mat, pose)
                put(f'manga_{mat}_esq_{g}', lft, 'body')
                put(f'manga_{mat}_{pose}_{g}', rup, 'body')
                put(f'manga_{mat}_{pose}_ante_{g}', rfo, 'body')
        for cid in COATS:
            bk, fr = trench(cid, r)
            put(f'{cid}_tras_{g}', bk, 'body'); put(f'{cid}_{g}', fr, 'body')
        bk, fr = katana(r); put(f'arm_lamina_tras_{g}', bk, 'body')
        layers.pop(f'arm_lamina_{g}', None)
        bk, fr = thermal_hammer(r); put(f'arm_martelo_tras_{g}', bk, 'body'); put(f'arm_martelo_{g}', fr, 'body')
    return layers


if __name__ == '__main__':
    out = build()
    json.dump(out, open(sys.argv[1], 'w'), separators=(',', ':'))
    print(len(out), 'camadas')
