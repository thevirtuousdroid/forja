"""Motor de pixel art do Forja: formas com volume, luz direcional e dithering ordenado.

Cada camada guarda, por pixel, um material (letra) e um nível de luz (0 = sombra ... 4 = brilho).
As cores reais vêm de paletas trocáveis (pele, cabelo, olhos), aplicadas na hora de montar.
"""
import numpy as np
from PIL import Image, ImageDraw

LIGHT = np.array([-0.55, -0.62, 0.56])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16 - 0.5


class Layer:
    def __init__(self, w=64, h=64):
        self.w, self.h = w, h
        self.mat = np.full((h, w), '', dtype=object)
        self.lvl = np.zeros((h, w), dtype=int)

    # ── máscaras ──────────────────────────────────────────────────────────
    def mask_poly(self, pts):
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
        return np.asarray(im) > 0

    def mask_ellipse(self, cx, cy, rx, ry):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0

    def mask_line(self, pts, width):
        im = Image.new('L', (self.w, self.h), 0)
        d = ImageDraw.Draw(im)
        d.line([tuple(p) for p in pts], fill=255, width=width, joint='curve')
        for p in (pts[0], pts[-1]):
            r = width / 2
            d.ellipse([p[0] - r + 0.5, p[1] - r + 0.5, p[0] + r - 0.5, p[1] + r - 0.5], fill=255)
        return np.asarray(im) > 0

    # ── pintura ───────────────────────────────────────────────────────────
    def _put(self, mask, mat, lvl):
        self.mat[mask] = mat
        self.lvl[mask] = np.clip(lvl, 0, 4)[mask] if np.ndim(lvl) else lvl

    def flat(self, mask, mat, lvl):
        self._put(mask, mat, lvl)

    def _quant(self, l, bias, spread, dither=0.35):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        v = 2.0 + bias + l * spread + BAYER[yy % 4, xx % 4] * dither * 2
        return np.clip(np.floor(v + 0.5), 0, 4).astype(int)

    def ellipsoid(self, mask, cx, cy, rx, ry, mat, bias=0.0, spread=2.4, dither=0.35):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        nx = np.clip((xx + 0.5 - cx) / rx, -1, 1)
        ny = np.clip((yy + 0.5 - cy) / ry, -1, 1)
        nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0.02, 1))
        l = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
        self._put(mask, mat, self._quant(l, bias, spread, dither))

    def cylinder(self, mask, mat, bias=0.0, spread=2.4, tilt=0.0, dither=0.35, axis='v'):
        """Sombreia a forma como um cilindro vertical (ou horizontal), pelas bordas da própria máscara."""
        nx = np.zeros((self.h, self.w))
        ny = np.zeros((self.h, self.w))
        if axis == 'v':
            for y in range(self.h):
                xs = np.where(mask[y])[0]
                if len(xs) == 0:
                    continue
                c, r = (xs[0] + xs[-1] + 1) / 2, max((xs[-1] - xs[0] + 1) / 2, 1)
                nx[y, xs] = np.clip((xs + 0.5 - c) / r, -0.97, 0.97)
            ys = np.where(mask.any(1))[0]
            if len(ys):
                t = (np.arange(self.h) - ys[0]) / max(ys[-1] - ys[0], 1)
                ny += (tilt * (0.5 - t))[:, None] * -1
        else:
            for x in range(self.w):
                ys = np.where(mask[:, x])[0]
                if len(ys) == 0:
                    continue
                c, r = (ys[0] + ys[-1] + 1) / 2, max((ys[-1] - ys[0] + 1) / 2, 1)
                ny[ys, x] = np.clip((ys + 0.5 - c) / r, -0.97, 0.97)
        nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0.02, 1))
        l = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
        self._put(mask, mat, self._quant(l, bias, spread, dither))

    def px(self, x, y, mat, lvl):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.mat[y, x] = mat
            self.lvl[y, x] = lvl

    def erase(self, mask):
        self.mat[mask] = ''

    def mask(self):
        return self.mat != ''

    def encode(self):
        out = []
        for y in range(self.h):
            for x in range(self.w):
                m = self.mat[y, x]
                out.append(f'{m}{self.lvl[y, x]}' if m else '..')
        return ''.join(out)


def _capsule_field(L, p0, p1, r0, r1):
    """Distância ao eixo de um segmento com raio variável: devolve máscara e normais."""
    yy, xx = np.mgrid[0:L.h, 0:L.w]
    px_, py_ = xx + 0.5, yy + 0.5
    ax, ay = p1[0] - p0[0], p1[1] - p0[1]
    ll = max(ax * ax + ay * ay, 1e-6)
    t = np.clip(((px_ - p0[0]) * ax + (py_ - p0[1]) * ay) / ll, 0, 1)
    cx, cy = p0[0] + ax * t, p0[1] + ay * t
    r = r0 + (r1 - r0) * t
    dx, dy = (px_ - cx) / r, (py_ - cy) / r
    d2 = dx * dx + dy * dy
    return d2 <= 1.0, dx, dy, d2


def capsule(L, p0, p1, r0, r1, mat, bias=0.0, spread=2.6, dither=0.2, clip=None):
    """Membro com volume (braço, perna, pescoço): cilindro afunilado com pontas arredondadas."""
    m, dx, dy, d2 = _capsule_field(L, p0, p1, r0, r1)
    if clip is not None:
        m = m & clip
    nz = np.sqrt(np.clip(1 - d2, 0.02, 1))
    l = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]
    L._put(m, mat, L._quant(l, bias, spread, dither))
    return m


Layer.capsule = capsule
