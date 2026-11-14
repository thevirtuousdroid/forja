"""Forja · itens que ainda eram medievais, redesenhados no tema cyberpunk (mesmos nomes de item).

faixa → bandana tática com LED · Elmo do Silêncio → máscara fechada com visor
cota de malha → colete tático de fibra · placas → exoesqueleto · cajado → bastão de energia
Martelo do Juiz → martelo hidráulico dourado · amuletos → chip, cristal de dados, disco de equilíbrio
Gera layers7.json a partir de character5.
"""
import json, sys
import numpy as np
import character5 as c5  # aplica o ajuste de dithering
import character3 as c3
from character2 import Part, RIG, mirror, ell, grip
from engine import raw, SCALE as S

KW = dict(spread=2.9, dither=0.1)


def P1(L, x, y, m, v):
    L.px1(x, y, m, v)


# ── cabeça ──────────────────────────────────────────────────────────────────

def tech_headband(r):
    """Faixa de ferreiro → bandana tática: faixa escura com fita de LED, módulo e antena, cabos atrás."""
    L = Part()
    hx, hy, rx, ry = r['head']
    for side in (1,):  # cabos caindo atrás da orelha
        for k in range(2):
            a = (hx + side * (rx + 0.2), hy - 3.6 + k * 0.9)
            L.part(); L.capsule(a, (a[0] + side * (1.6 + k), hy + 3.5 + k * 1.6), 0.45, 0.45, 'D', bias=0.0, **KW)
    band = L.mask_poly([(hx - rx - 0.7, hy - 5.4), (hx + rx + 0.7, hy - 5.4), (hx + rx + 0.5, hy - 2.6), (hx - rx - 0.5, hy - 2.6)])
    L.part(); L.cylinder(band, 'D', bias=0.15, **KW)
    for X in range(int((hx - rx) * S), int((hx + rx) * S) + 1):   # fita de LED segmentada
        x = X / S
        if X % 4 != 3:
            P1(L, x, hy - 4.0, 'T', 4 if X % 4 == 1 else 3)
        P1(L, x, hy - 3.5, 'T', 1)
    for X in range(int((hx - rx - 0.4) * S), int((hx + rx + 0.4) * S)):  # costuras
        P1(L, X / S, hy - 5.2, 'D', 4)
        P1(L, X / S, hy - 2.8, 'D', 0)
    mx = hx + rx + 0.4
    mod = L.mask_ellipse(mx, hy - 4.0, 1.8, 1.9)
    L.part(); L.ellipsoid(mod, mx - 0.6, hy - 4.6, 1.8, 1.9, 'M', bias=0.25, **KW)
    L.px(int(mx), int(hy - 4), 'P', 4)
    L.part(); L.capsule((mx + 0.6, hy - 5.4), (mx + 2.2, hy - 10.5), 0.35, 0.3, 'M', bias=0.2, **KW)
    L.px(int(mx + 2.2), int(hy - 11), 'P', 4)
    L.seams()
    return L


def silence_mask(r):
    """Elmo do Silêncio → máscara fechada: casco liso, visor em fenda magenta, filtros na boca, fones."""
    L = Part()
    hx, hy, rx, ry = r['head']
    y = r['eye_y']
    cw, cy = r['chin']
    for side in (-1, 1):  # fones de isolamento
        ear = L.mask_ellipse(hx + side * (rx + 0.9), hy + 1.2, 2.3, 3.2)
        L.part(); L.ellipsoid(ear, hx + side * (rx + 0.9) - 0.7, hy + 0.4, 2.3, 3.2, 'M', bias=0.15, **KW)
    dome = L.mask_ellipse(hx, hy - 0.6, rx + 1.3, ry + 0.9)
    jaw = L.mask_poly([(hx - rx - 1.1, hy), (hx + rx + 1.1, hy), (hx + rx - 0.6, hy + 6), (hx + cw + 1.2, cy + 0.8),
                       (hx - cw - 1.2, cy + 0.8), (hx - rx + 0.6, hy + 6)])
    shell = dome | jaw
    L.part(); L.ellipsoid(shell, hx - 2.2, hy - 3, rx + 2.6, ry + 3, 'D', bias=0.05, spread=3.0, dither=0.08)
    for Y in range(int((hy - ry) * S), int((y - 1.4) * S)):  # vinco central do casco
        P1(L, hx + 0.25, Y / S, 'D', 0)
    for (x, yy) in [(hx - 4, hy - ry + 1.2), (hx - 3.5, hy - ry + 0.8), (hx - 5, hy - ry + 2.2)]:
        L.px(int(x), int(yy), 'M', 4)  # brilho
    visor = L.mask_poly([(hx - rx + 0.4, y - 1.6), (hx + rx - 0.4, y - 1.6), (hx + rx - 0.9, y + 1.0), (hx - rx + 0.9, y + 1.0)])
    L.part(); L.flat(visor, 'P', 1)
    for X in range(int((hx - rx + 0.6) * S), int((hx + rx - 0.4) * S)):
        P1(L, X / S, y - 1.4, 'P', 3)
        P1(L, X / S, y - 0.2, 'P', 4 if abs(X / S - hx + 2.5) < 1.2 else 2)  # linha de leitura com ponto que corre
    # filtros da boca
    f = L.mask_poly([(hx - 3.0, y + 4.2), (hx + 3.0, y + 4.2), (hx + 2.2, y + 8.2), (hx - 2.2, y + 8.2)])
    L.part(); L.cylinder(f, 'M', bias=0.0, **KW)
    for k in range(4):
        for X in range(int((hx - 2.2) * S), int((hx + 2.2) * S)):
            P1(L, X / S, y + 5.0 + k, 'D', 0)
    for side in (-1, 1):
        L.px(int(hx + side * (rx + 0.9)), int(hy + 1), 'P', 4)
        L.px(int(hx + side * (rx + 0.9)), int(hy + 2), 'P', 2)
    L.seams()
    return L


# ── roupas ──────────────────────────────────────────────────────────────────

def tactical_mesh(r):
    """Cota de malha → colete tático de fibra de carbono, painéis na cor da roupa, bolsos e friso de neon."""
    L = Part()
    m = c3.torso_mask(L, r, 0.06)
    L.part(); L.cylinder(m, 'D', bias=-0.1, tilt=0.4, **KW)
    M, V = raw(L.mat), raw(L.lvl)
    on = raw(m)
    ys, xs = np.where(on)
    for Y, X in zip(ys, xs):  # trama de fibra de carbono
        if ((X // 2) + (Y // 2)) % 2 == 0:
            V[Y, X] = min(4, V[Y, X] + 1)
        elif (X + Y) % 4 == 0:
            V[Y, X] = max(0, V[Y, X] - 1)
    for side in (-1, 1):  # painéis laterais na cor da roupa
        pts = [(48 + side * 6.5, 37), (48 + side * 11, 34), (48 + side * 10, 47), (48 + side * 6, 47)]
        L.part(); L.cylinder(L.mask_poly(pts) & m, 'C', bias=0.1, **KW)
    # gola em V com friso de neon
    for t in np.linspace(0, 1, 24):
        for side in (-1, 1):
            x = 48 + side * (4.6 - 4.6 * t); y = 27.4 + 6.2 * t
            P1(L, x, y, 'T', 4 if int(t * 24) % 3 else 3)
    # bolsos do peito (porta-carregador)
    by = 39.5 if not r['female'] else 41
    for k, dx in enumerate((-4.2, 0, 4.2)):
        pk = L.mask_poly([(48 + dx - 1.8, by), (48 + dx + 1.8, by), (48 + dx + 1.7, by + 5), (48 + dx - 1.7, by + 5)])
        L.part(); L.cylinder(pk, 'C', bias=0.0, **KW)
        for X in range(int((48 + dx - 1.6) * S), int((48 + dx + 1.6) * S)):
            P1(L, X / S, by + 1.2, 'C', 0)  # aba
        L.px(int(48 + dx), int(by + 1), 'M', 3)
    L.seams()
    return L


def exo_armor(r):
    """Armadura de placas → exoesqueleto: peito blindado, abdome em segmentos, núcleo de energia, pistões."""
    L = Part()
    fem = r['female']
    m = c3.torso_mask(L, r, 0.08)
    chest = m.copy(); raw(chest)[int((40 if not fem else 41) * S):, :] = False
    L.part(); L.cylinder(chest, 'M', bias=0.0, tilt=0.5, spread=3.0, dither=0.08)
    for Y in range(int(28 * S), int(40 * S)):  # sulco central
        if raw(chest)[Y, int(48 * S)]:
            P1(L, 48, Y / S, 'M', 0)
    y0 = 40.6 if not fem else 41.5
    for k in range(3):  # segmentos do abdome
        seg = m & L.mask_poly([(36, y0 + k * 2.3), (60, y0 + k * 2.3), (60, y0 + k * 2.3 + 1.9), (36, y0 + k * 2.3 + 1.9)])
        seg &= L.mask_ellipse(48, y0 + 3, 7.4 - k * 0.6, 8)
        L.part(); L.cylinder(seg, 'D', bias=0.2 - k * 0.1, **KW)
    cyc = 34.5 if not fem else 35.5  # núcleo
    ring = L.mask_ellipse(48, cyc, 2.6, 2.6)
    L.part(); L.ellipsoid(ring, 47.4, cyc - 0.6, 2.6, 2.6, 'D', bias=0.1, **KW)
    core = L.mask_ellipse(48, cyc, 1.6, 1.6)
    L.part(); L.ellipsoid(core, 47.5, cyc - 0.5, 1.6, 1.6, 'O', bias=0.9, spread=1.6, dither=0.05)
    for side in (0, 1):
        sx, sy = r['sh'] if side == 0 else mirror(r['sh'])
        sg = -1 if side == 0 else 1
        # pistão do ombro até o peito
        L.part(); L.capsule((sx + sg * 1.0, sy + 1.6), (48 + sg * 4.6, 33.5), 0.6, 0.6, 'M', bias=0.3, **KW)
        L.px(int(48 + sg * 4.6), 33, 'D', 0)
        # ombreira pequena e angulosa
        pts = [(sx - 3.6, sy + 1.6), (sx - 2.6, sy - 2.2), (sx + 2.4, sy - 2.8), (sx + 3.8, sy + 1.0), (sx + 0.4, sy + 2.4)]
        if side:
            pts = [(2 * sx - p[0], p[1]) for p in pts]
        L.part(); L.cylinder(L.mask_poly(pts), 'M', bias=0.2, **KW)
        for t in np.linspace(-1.8, 1.8, 7):
            P1(L, sx + t, sy - 0.6 + abs(t) * 0.12, 'O', 3)  # faixa de luz
    for X in range(int(43 * S), int(53 * S)):  # gola
        P1(L, X / S, 27.6, 'D', 1)
    L.seams()
    return L


# ── armas ───────────────────────────────────────────────────────────────────

def energy_staff(r):
    """Cajado do Erudito → bastão de energia: haste de metal com luz, emissor em garra e anel flutuante."""
    L = Part()
    hx_, hy_ = mirror((r['hand'][0], r['hand'][1]))
    x = hx_ + 0.4
    L.part(); L.capsule((x, 90), (x - 0.3, 13), 1.0, 0.9, 'D', bias=0.1, **KW)
    for y in range(18, 86, 7):  # segmentos de luz na haste
        L.px(int(x), y, 'T', 3); L.px(int(x), y + 1, 'T', 2)
    for y in np.arange(hy_ - 5, hy_ + 5, 1.0):  # empunhadura
        P1(L, x - 0.5, y, 'J', 1); P1(L, x, y, 'J', 2); P1(L, x + 0.5, y + 0.5, 'J', 0)
    L.part(); L.capsule((x, 88), (x - 0.1, 91), 1.3, 1.0, 'M', bias=0.3, **KW)
    L.px(int(x), 90, 'O', 4)
    for side in (-1, 1):  # garras do emissor
        L.part(); L.capsule((x, 14), (x + side * 2.6, 7.5), 0.7, 0.5, 'M', bias=0.25, **KW)
        L.part(); L.capsule((x + side * 2.6, 7.5), (x + side * 1.6, 4.0), 0.5, 0.4, 'M', bias=0.25, **KW)
    core = L.mask_ellipse(x - 0.1, 8.6, 1.9, 2.3)
    L.part(); L.ellipsoid(core, x - 0.7, 8.0, 1.9, 2.3, 'T', bias=0.9, spread=1.6, dither=0.05)
    rg = L.mask_ellipse(x, 8.6, 4.6, 1.3) & ~L.mask_ellipse(x, 8.6, 3.6, 0.6)
    for (Y, X) in zip(*np.where(raw(rg))):  # anel holográfico (com falhas)
        if (X // 3) % 4 != 3:
            P1(L, X / S, Y / S, 'T', 4 if Y / S < 8.6 else 3)
    L.seams()
    return L, None


def judge_hammer(r):
    """Martelo do Juiz → martelo hidráulico dourado: cabeça grande, pistões e faixa de luz."""
    back, front = c3.big_hammer(r, scale=1.16, gold=True)
    _, hand, s_top, d = grip(r)
    sc = 1.16
    p = np.array([d[1], -d[0]]); p = -p if p[0] < 0 else p
    end = np.array(s_top) + d * (11.0 + (sc - 1) * 4)
    M, V = raw(back.mat), raw(back.lvl)
    M[M == 'O'] = 'P'  # a runa de brasa vira um sinal magenta
    M[M == 'R'] = 'D'  # cabo de metal escuro em vez de madeira
    FM = raw(front.mat); FM[FM == 'R'] = 'D'
    for t in (0.2, 0.35, 0.9):  # anéis de luz no cabo
        q = np.array(hand) - d * 6.0 + (np.array(s_top) - (np.array(hand) - d * 6.0)) * t
        front.px(int(round(q[0])), int(round(q[1])), 'P', 3)
    for side in (-1, 1):
        for t in np.linspace(5.4 * sc, 7.8 * sc, 3):  # pistões
            for s_ in (-1, 1):
                q = end + p * side * t + d * s_ * (3.9 * sc)
                back.px(int(round(q[0])), int(round(q[1])), 'M', 4)
        for t in np.linspace(-3.4 * sc, 3.4 * sc, 13):  # faixa de luz na face
            q = end + p * side * 10.2 * sc + d * t
            back.px(int(round(q[0])), int(round(q[1])), 'Y', 4 if abs(t) < 1.2 else 3)
    return back, front


# ── amuletos ────────────────────────────────────────────────────────────────

def amulet_cyber(aid, r):
    L = Part()
    cy = 37.5 if not r['female'] else 35.2
    for side in (-1, 1):  # cabo fino com conectores
        for t in np.linspace(0, 1, 20):
            x = 48 + side * (4.8 - 4.4 * t); y = 28.8 + (cy - 30.6) * t
            P1(L, x, y, 'D', 3)
        x = 48 + side * 2.6; y = 28.8 + (cy - 30.6) * 0.5
        L.px(int(x), int(y), 'M', 3)
    if aid == 'amu_ampulheta':  # chip com ampulheta holográfica
        m = L.mask_poly([(45.2, cy - 1.2), (50.8, cy - 1.2), (50.8, cy + 5.4), (45.2, cy + 5.4)])
        L.part(); L.cylinder(m, 'D', bias=0.1, **KW)
        for X in range(int(45.2 * S), int(50.8 * S)):
            P1(L, X / S, cy - 1.2, 'M', 3); P1(L, X / S, cy + 5.0, 'M', 1)
        for k in range(9):  # dois triângulos em linha fina
            t = k / 8
            P1(L, 46.2 + 3.6 * t, cy - 0.2, 'T', 4)
            P1(L, 46.2 + 3.6 * t, cy + 4.2, 'T', 3)
            P1(L, 46.2 + 1.8 * t, cy - 0.2 + 2.2 * t, 'T', 3)
            P1(L, 49.8 - 1.8 * t, cy - 0.2 + 2.2 * t, 'T', 3)
            P1(L, 48.0 - 1.8 * t, cy + 2.0 + 2.2 * t, 'T', 3)
            P1(L, 48.0 + 1.8 * t, cy + 2.0 + 2.2 * t, 'T', 3)
        for (dx, dy) in ((-0.5, 3.7), (0, 3.7), (0.5, 3.7), (0, 3.2), (0, 2.4)):
            P1(L, 48 + dx, cy + dy, 'O', 4)  # areia
    elif aid == 'amu_calma':  # cristal de dados preso em garra
        m = L.mask_poly([(48, cy - 1.6), (50.2, cy + 0.6), (50.2, cy + 3.6), (48, cy + 5.8), (45.8, cy + 3.6), (45.8, cy + 0.6)])
        L.part(); L.ellipsoid(m, 47.2, cy + 1.2, 2.8, 3.6, 'T', bias=0.5, spread=2.0, dither=0.05)
        for Y in range(int((cy - 1.2) * S), int((cy + 5.4) * S)):
            P1(L, 48, Y / S, 'T', 4 if (Y // 2) % 2 else 2)  # faceta
        for dy in (-1.8, 5.8):
            cl = L.mask_poly([(46.6, cy + dy - 0.6), (49.4, cy + dy - 0.6), (49.0, cy + dy + 0.6), (47.0, cy + dy + 0.6)])
            L.part(); L.cylinder(cl, 'M', bias=0.3, **KW)
    elif aid == 'amu_equilibrio':  # disco com metade ciano e metade laranja
        m = L.mask_ellipse(48, cy + 2, 3.0, 3.0)
        L.part(); L.ellipsoid(m, 47.2, cy + 1.2, 3.0, 3.0, 'M', bias=0.2, **KW)
        inner = L.mask_ellipse(48, cy + 2, 2.0, 2.0)
        ys, xs = np.where(raw(inner))
        for Y, X in zip(ys, xs):
            x, y = X / S, Y / S
            s = (x - 48) + 0.9 * np.sin((y - cy - 2) * 1.6)  # curva em S
            P1(L, x, y, 'T' if s < 0 else 'O', 3 if (X + Y) % 3 else 4)
        P1(L, 47.2, cy + 1.0, 'O', 4); P1(L, 48.8, cy + 3.0, 'T', 4)
    L.seams()
    return L


def build():
    layers = c5.build()

    def put(name, L, part):
        if L is not None and (L.mat != '').any():
            layers[name] = dict(px=L.encode(), part=part)
    for g, r in RIG.items():
        put(f'cab_faixa_{g}', tech_headband(r), 'head')
        put(f'cab_elmo_silencio_{g}', silence_mask(r), 'head')
        put(f'cor_malha_{g}', tactical_mesh(r), 'body')
        put(f'cor_placas_{g}', exo_armor(r), 'body')
        bk, _ = energy_staff(r); put(f'arm_cajado_tras_{g}', bk, 'body')
        bk, fr = judge_hammer(r); put(f'arm_martelo_juiz_tras_{g}', bk, 'body'); put(f'arm_martelo_juiz_{g}', fr, 'body')
        for aid in ('amu_ampulheta', 'amu_calma', 'amu_equilibrio'):
            put(f'{aid}_{g}', amulet_cyber(aid, r), 'body')
    return layers


if __name__ == '__main__':
    out = build()
    json.dump(out, open(sys.argv[1], 'w'), separators=(',', ':'))
    print(len(out), 'camadas')
