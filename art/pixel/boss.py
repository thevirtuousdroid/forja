"""A Hidra das Notificações em pixel art (96x96, 4 quadros): núcleo de ferro aceso e pescoços de cabo
terminando em aparelhos de distração (celular, TV, controle, notebook e óculos de realidade virtual)."""
import json, sys, math
import numpy as np
from engine import Layer
import render

render.FIXED['P'] = ['#3a0a2e', '#6a1250', '#a81e7a', '#e040a8', '#ff9ad8']
W = H = 96


def bezier(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]) for t in np.linspace(0, 1, n)]


def screen(L, x0, y0, x1, y1, mat, frame, kind):
    m = L.mask_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
    L.flat(m, mat, 2)
    for y in range(int(y0), int(y1)):
        for x in range(int(x0), int(x1)):
            if kind == 'static' and (x * 7 + y * 13 + frame * 5) % 5 == 0:
                L.px(x, y, mat, 4)
            elif kind == 'scan' and (y + frame) % 3 == 0:
                L.px(x, y, mat, 3)
    return m


def device(L, kind, cx, cy, frame):
    if kind == 'celular':
        body = L.mask_poly([(cx - 6, cy - 10), (cx + 6, cy - 10), (cx + 7, cy - 9), (cx + 7, cy + 9), (cx + 6, cy + 10),
                            (cx - 6, cy + 10), (cx - 7, cy + 9), (cx - 7, cy - 9)])
        L.cylinder(body, 'D', bias=0.0, spread=2.4)
        screen(L, cx - 5, cy - 8, cx + 6, cy + 8, 'P', frame, 'scan')
        for i, yy in enumerate((cy - 6, cy - 2, cy + 2)):  # bolhas de notificação
            on = (i + frame) % 3 != 0
            for x in range(cx - 4, cx + 4 - i * 2):
                L.px(x, yy, 'T' if on else 'P', 4 if on else 3)
                L.px(x, yy + 1, 'T' if on else 'P', 3 if on else 3)
        L.px(cx + 4, cy - 7, 'O', 4)
    elif kind == 'tv':
        box = L.mask_poly([(cx - 11, cy - 8), (cx + 11, cy - 8), (cx + 11, cy + 8), (cx - 11, cy + 8)])
        L.cylinder(box, 'R', bias=0.1, spread=2.4)
        screen(L, cx - 9, cy - 6, cx + 5, cy + 6, 'T', frame, 'static')
        for k in (0, 1):
            L.px(cx + 8, cy - 3 + k * 4, 'D', 3)
            L.px(cx + 8, cy - 2 + k * 4, 'O', 3)
        ant = L.mask_line([(cx - 2, cy - 8), (cx - 7, cy - 17)], 1) | L.mask_line([(cx + 2, cy - 8), (cx + 8, cy - 16)], 1)
        L.flat(ant, 'M', 3)
        L.px(cx - 7, cy - 17, 'P', 4)
        L.px(cx + 8, cy - 16, 'T', 4)
    elif kind == 'controle':
        body = L.mask_ellipse(cx - 5, cy + 1, 6, 5) | L.mask_ellipse(cx + 5, cy + 1, 6, 5) | \
            L.mask_poly([(cx - 6, cy - 4), (cx + 6, cy - 4), (cx + 6, cy + 3), (cx - 6, cy + 3)])
        L.ellipsoid(body, cx - 2, cy - 2, 12, 7, 'D', bias=0.2, spread=2.4)
        for dx, dy in ((-6, 0), (-7, 1), (-5, 1), (-6, 2)):
            L.px(cx + dx, cy + dy, 'M', 3)
        for (dx, dy, mt) in ((5, -1, 'T'), (7, 1, 'P'), (5, 3, 'O'), (3, 1, 'T')):
            L.px(cx + dx, cy + dy, mt, 4 if (frame + dx) % 2 else 3)
        L.px(cx, cy - 2, 'P', 4)
    elif kind == 'notebook':
        lid = L.mask_poly([(cx - 10, cy - 9), (cx + 10, cy - 9), (cx + 10, cy + 4), (cx - 10, cy + 4)])
        L.cylinder(lid, 'D', bias=0.0)
        screen(L, cx - 8, cy - 7, cx + 9, cy + 3, 'T', frame, 'scan')
        for x in range(cx - 6, cx + 2):  # um "play" no centro
            pass
        for k in range(4):
            for y in range(cy - 4 + k, cy + 1 - k):
                L.px(cx - 1 + k, y, 'W', 4)
        base = L.mask_poly([(cx - 12, cy + 4), (cx + 12, cy + 4), (cx + 10, cy + 7), (cx - 10, cy + 7)])
        L.cylinder(base, 'M', bias=0.2, axis='h')
    elif kind == 'vr':
        visor = L.mask_poly([(cx - 10, cy - 5), (cx + 10, cy - 5), (cx + 11, cy - 3), (cx + 11, cy + 4), (cx + 9, cy + 6),
                             (cx + 2, cy + 6), (cx, cy + 3), (cx - 2, cy + 6), (cx - 9, cy + 6), (cx - 11, cy + 4), (cx - 11, cy - 3)])
        L.ellipsoid(visor, cx - 2, cy - 3, 12, 8, 'D', bias=0.1, spread=2.6)
        for x in range(cx - 8, cx + 9):
            L.px(x, cy - 1, 'T', 4 if (x + frame) % 4 else 3)
            L.px(x, cy, 'T', 2)
        L.px(cx - 9, cy - 4, 'M', 4)


def hydra(frame):
    L = Layer(W, H)
    hub = (48, 76)
    heads = [('tv', 47, 18, 0.0), ('celular', 20, 30, 1.1), ('controle', 75, 26, 2.3), ('vr', 17, 58, 3.4), ('notebook', 79, 55, 4.6)]
    pos = []
    for kind, x, y, ph in heads:
        sway = math.sin(frame * math.pi / 2 + ph)
        pos.append((kind, int(round(x + sway * 1.5)), int(round(y + math.cos(frame * math.pi / 2 + ph) * 1.2))))
    # pescoços: cabos grossos com uma linha de luz
    for (kind, x, y), (_, _, _, ph) in zip(pos, heads):
        ctrl = ((hub[0] + x) / 2 + (8 if x < hub[0] else -8), (hub[1] + y) / 2 + 6)
        pts = bezier((hub[0] + (x - hub[0]) * 0.18, hub[1] - 6), ctrl, (x, y + 6))
        m = L.mask_line(pts, 7)
        L.cylinder(m, 'D', bias=-0.1, spread=2.6, dither=0.2)
        mat = 'P' if kind in ('celular', 'vr') else 'T'
        for i, (px_, py_) in enumerate(pts[2:-2]):
            if (i + frame * 2) % 7 != 0:
                L.px(int(round(px_)), int(round(py_)), mat, 3 if (i + frame) % 3 else 4)
    # núcleo blindado
    dome = L.mask_ellipse(48, 78, 20, 14)
    dome[86:, :] = False
    L.ellipsoid(dome, 44, 72, 20, 14, 'D', bias=0.15, spread=2.8, dither=0.18)
    plates = L.mask_poly([(30, 86), (66, 86), (70, 92), (26, 92)])
    L.cylinder(plates, 'M', bias=-0.9, axis='h')
    for x in range(36, 61):  # fornalha
        for y in (79, 80, 81):
            if dome[y, x]:
                lv = 4 if 44 <= x <= 52 and y == 80 else 3 if 40 <= x <= 56 else 2
                L.px(x, y, 'O', lv if (x + frame) % 6 else max(2, lv - 1))
    for ex, sgn in ((40, 1), (56, -1)):  # olhos da fornalha, inclinados para o centro (bravos)
        for k, dx in enumerate(range(-3, 4)):
            yy = 70 + ((dx + 3) // 2 if sgn > 0 else (3 - dx) // 2)
            L.px(ex + dx, yy, 'O', 4 if abs(dx) < 2 else 3)
            L.px(ex + dx, yy + 1, 'O', 2)
    for x in (34, 62):
        L.px(x, 75, 'T', 4)
    for kind, x, y in pos:
        device(L, kind, x, y, frame)
    return L


if __name__ == '__main__':
    pal = render.palette('clara', 'preto', 'castanho')
    frames = []
    for f in range(4):
        L = hydra(f)
        rgba = render.compose({'h': {'px': L.encode()}}, ['h'], pal, W, H)
        frames.append(rgba)
    # folha de quadros (RGBA, sem fundo) para a página
    from PIL import Image
    sheet = np.concatenate(frames, axis=1)
    img = Image.fromarray(np.uint8(np.dstack([sheet[..., :3], sheet[..., 3] * 255])), 'RGBA')
    img.save(sys.argv[1])
    prev = render.to_image(np.dstack([frames[0][..., :3], frames[0][..., 3]]), 4)
    prev.save(sys.argv[2])
    print('ok')
