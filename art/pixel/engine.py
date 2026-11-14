"""Motor de pixel art do Forja: formas com volume, luz direcional e dithering ordenado.

Cada camada guarda, por pixel, um material (letra) e um nível de luz (0 = sombra ... 4 = brilho).
As cores reais vêm de paletas trocáveis (pele, cabelo, olhos), aplicadas na hora de montar.
"""
import numpy as np
from PIL import Image, ImageDraw

SCALE = 2  # cada unidade do desenho vira 2x2 pixels: dobra a resolução sem mudar o código das peças


class Hi(np.ndarray):
    """Array em alta resolução que aceita índices na grade original: [y, x] e [a:, :] são convertidos."""
    def __new__(cls, a):
        return np.asarray(a).view(cls)

    @staticmethod
    def _map(key):
        S = SCALE
        if isinstance(key, tuple) and len(key) == 2:
            y, x = key
            if isinstance(y, (int, np.integer)) and isinstance(x, (int, np.integer)):
                return (slice(int(y) * S, int(y) * S + S), slice(int(x) * S, int(x) * S + S)), True
            if isinstance(y, slice) and y.start is not None and y.stop is None and y.step is None and x == slice(None):
                return (slice(int(y.start) * S, None), slice(None)), False
        return key, False

    def __getitem__(self, key):
        k, scalar = self._map(key)
        r = self.view(np.ndarray)[k]
        if scalar:
            v = np.asarray(r)[0, 0] if np.ndim(r) else r
            return v.item() if hasattr(v, 'item') else v
        return r

    def __setitem__(self, key, value):
        k, _ = self._map(key)
        self.view(np.ndarray)[k] = value


def raw(a):
    return np.asarray(a).view(np.ndarray)


LIGHT = np.array([-0.55, -0.62, 0.56])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16 - 0.5


class Layer:
    def __init__(self, w=64, h=64):
        self.w, self.h = w * SCALE, h * SCALE
        self.mat = Hi(np.full((self.h, self.w), '', dtype=object))
        self.lvl = Hi(np.zeros((self.h, self.w), dtype=int))

    # ── máscaras ──────────────────────────────────────────────────────────
    def mask_poly(self, pts):
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([(p[0] * SCALE, p[1] * SCALE) for p in pts], fill=255)
        return Hi(np.asarray(im) > 0)

    def mask_ellipse(self, cx, cy, rx, ry):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        S = SCALE
        return Hi(((xx + 0.5 - cx * S) / (rx * S)) ** 2 + ((yy + 0.5 - cy * S) / (ry * S)) ** 2 <= 1.0)

    def mask_line(self, pts, width):
        im = Image.new('L', (self.w, self.h), 0)
        d = ImageDraw.Draw(im)
        S = SCALE
        pts = [(p[0] * S, p[1] * S) for p in pts]
        width = int(round(width * S))
        d.line(pts, fill=255, width=width, joint='curve')
        for p in (pts[0], pts[-1]):
            r = width / 2
            d.ellipse([p[0] - r + 0.5, p[1] - r + 0.5, p[0] + r - 0.5, p[1] + r - 0.5], fill=255)
        return Hi(np.asarray(im) > 0)

    # ── pintura ───────────────────────────────────────────────────────────
    def _put(self, mask, mat, lvl):
        mask = raw(mask)
        raw(self.mat)[mask] = mat
        raw(self.lvl)[mask] = np.clip(lvl, 0, 4)[mask] if np.ndim(lvl) else lvl

    def flat(self, mask, mat, lvl):
        self._put(mask, mat, lvl)

    def _quant(self, l, bias, spread, dither=0.35):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        v = 2.0 + bias + l * spread + BAYER[yy % 4, xx % 4] * dither * 2
        return np.clip(np.floor(v + 0.5), 0, 4).astype(int)

    def ellipsoid(self, mask, cx, cy, rx, ry, mat, bias=0.0, spread=2.4, dither=0.35):
        S = SCALE
        cx, cy, rx, ry = cx * S, cy * S, rx * S, ry * S
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        nx = np.clip((xx + 0.5 - cx) / rx, -1, 1)
        ny = np.clip((yy + 0.5 - cy) / ry, -1, 1)
        nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0.02, 1))
        l = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
        self._put(mask, mat, self._quant(l, bias, spread, dither))

    def cylinder(self, mask, mat, bias=0.0, spread=2.4, tilt=0.0, dither=0.35, axis='v'):
        """Sombreia a forma como um cilindro vertical (ou horizontal), pelas bordas da própria máscara."""
        mask = raw(mask)
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
        """Um "pixel" da grade original (um bloco SCALE x SCALE)."""
        S = SCALE
        x, y = int(x), int(y)
        if 0 <= x * S < self.w and 0 <= y * S < self.h:
            raw(self.mat)[y * S:y * S + S, x * S:x * S + S] = mat
            raw(self.lvl)[y * S:y * S + S, x * S:x * S + S] = lvl

    def px1(self, x, y, mat, lvl):
        """Um pixel fino, na resolução alta (coordenadas da grade original, com meio pixel)."""
        X, Y = int(round(x * SCALE)), int(round(y * SCALE))
        if 0 <= X < self.w and 0 <= Y < self.h:
            raw(self.mat)[Y, X] = mat
            raw(self.lvl)[Y, X] = lvl

    def hgrid(self):
        """Grade (yy, xx) em unidades da grade original, no tamanho da alta resolução."""
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return yy // SCALE, xx // SCALE

    def erase(self, mask):
        raw(self.mat)[raw(mask)] = ''

    def mask(self):
        return raw(self.mat) != ''

    def encode(self):
        M, V = raw(self.mat), raw(self.lvl)
        out = []
        for y in range(self.h):
            for x in range(self.w):
                m = M[y, x]
                out.append(f'{m}{V[y, x]}' if m else '..')
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
    S = SCALE
    m, dx, dy, d2 = _capsule_field(L, (p0[0] * S, p0[1] * S), (p1[0] * S, p1[1] * S), r0 * S, r1 * S)
    m = Hi(m)
    if clip is not None:
        m = m & clip
    nz = np.sqrt(np.clip(1 - d2, 0.02, 1))
    l = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]
    L._put(m, mat, L._quant(l, bias, spread, dither))
    return m


Layer.capsule = capsule
